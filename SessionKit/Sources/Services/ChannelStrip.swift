//
//  ChannelStrip.swift
//  SessionKit
//
//  Created by Alex Shubin on 19.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioUnitsKit
import AVFoundation
import OSLog

enum ChannelStripLoadError: Error, Equatable {
    case audioUnitInstantiationFailed
}

protocol ChannelStripType: Sendable {
    func load(_ slot: ChannelStripSlot, at position: Int) async throws(ChannelStripLoadError) -> LoadedAudioUnit
    func load(_ slots: [ChannelStripSlot?]) async -> [Result<LoadedAudioUnit, ChannelStripLoadError>?]
    func unload(at position: Int) async
    func reconnect() async
    func updateHardwareSettings(_ settings: SessionHardwareSettings?) async
}

final actor ChannelStrip: ChannelStripType {
    private struct Node {
        let avAudioUnit: AVAudioUnit
        let audioUnit: LoadedAudioUnit
    }

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "ChannelStrip")

    private let engine: AVAudioEngineType
    private let avAudioUnitFactory: AVAudioUnitFactoryType
    private let audioConnector: AudioConnectorType
    private let midiConnector: MidiConnectorType
    private var chain: [Int: Node] = [:]
    private var converters: [AVAudioMixerNode] = []
    private var hardwareSettings: SessionHardwareSettings?

    init(
        engine: AVAudioEngineType,
        avAudioUnitFactory: AVAudioUnitFactoryType,
        audioConnector: AudioConnectorType,
        midiConnector: MidiConnectorType
    ) {
        self.engine = engine
        self.avAudioUnitFactory = avAudioUnitFactory
        self.audioConnector = audioConnector
        self.midiConnector = midiConnector
    }

    func load(_ slot: ChannelStripSlot, at position: Int) async throws(ChannelStripLoadError) -> LoadedAudioUnit {
        stop()
        remove(at: position)
        let result = await insert(slot, at: position)
        start()
        return try result.get()
    }

    func load(_ slots: [ChannelStripSlot?]) async -> [Result<LoadedAudioUnit, ChannelStripLoadError>?] {
        stop()
        for position in chain.keys {
            remove(at: position)
        }
        let results = await withTaskGroup(of: (Int, Result<LoadedAudioUnit, ChannelStripLoadError>).self) { group in
            for (position, slot) in slots.enumerated() {
                guard let slot else { continue }
                group.addTask { (position, await self.insert(slot, at: position)) }
            }
            var results = [Result<LoadedAudioUnit, ChannelStripLoadError>?](repeating: nil, count: slots.count)
            for await (position, result) in group {
                results[position] = result
            }
            return results
        }
        start()
        return results
    }

    func unload(at position: Int) async {
        stop()
        remove(at: position)
        start()
    }

    func reconnect() async {
        guard !chain.isEmpty else { return }
        start()
    }

    func updateHardwareSettings(_ settings: SessionHardwareSettings?) async {
        let previous = hardwareSettings
        hardwareSettings = settings
        if settings?.audio != previous?.audio {
            await reconnect()
        } else if let midi = settings?.midi, midi != previous?.midi {
            midiConnector.reconnect(settings: midi)
        }
    }

    private func stop() {
        engine.stop()
        audioConnector.disconnect(in: engine)
        for converter in converters {
            engine.detach(converter)
        }
        converters.removeAll()
        midiConnector.disconnect()
    }

    private func start() {
        // Another operation may have started the engine while this one was suspended.
        stop()
        let nodes = chain.orderedValues
        guard let first = nodes.first, let last = nodes.last, let hardwareSettings else { return }
        let inputChannelCount = AVAudioChannelCount(hardwareSettings.audio.inputChannels.count)
        let input = first.avAudioUnit.acceptsAudioInput && inputChannelCount > 0
            ? inputNode(for: first.avAudioUnit, receiving: inputChannelCount)
            : nil
        guard audioConnector.connect(input: input, output: last.avAudioUnit, to: hardwareSettings.audio, in: engine) else { return }
        for (source, destination) in zip(nodes, nodes.dropFirst()) {
            let channelCount = source.avAudioUnit.outputChannelCount
            engine.connect(
                source.avAudioUnit,
                to: inputNode(for: destination.avAudioUnit, receiving: channelCount),
                format: engine.format(channelCount: channelCount)
            )
        }
        do {
            try engine.start()
        } catch {
            logger.warning("Engine start failed: \(String(describing: error), privacy: .public)")
        }
        midiConnector.connect(first.audioUnit, settings: hardwareSettings.midi)
    }

    /// The plug-in itself when it declares that input next to its output; otherwise a converter feeding the plug-in's own input format.
    private func inputNode(for plugin: AVAudioUnit, receiving channelCount: AVAudioChannelCount) -> AVAudioNode {
        guard !plugin.accepts(inputChannelCount: channelCount) else { return plugin }
        let converter = AVAudioMixerNode()
        engine.attach(converter)
        converters.append(converter)
        engine.connect(converter, to: plugin, format: engine.format(channelCount: plugin.inputChannelCount))
        return converter
    }

    private func insert(_ slot: ChannelStripSlot, at position: Int) async -> Result<LoadedAudioUnit, ChannelStripLoadError> {
        guard let avAudioUnit = try? await avAudioUnitFactory.instantiate(
            with: slot.component.componentDescription,
            options: .loadOutOfProcess
        ) else {
            return .failure(.audioUnitInstantiationFailed)
        }
        engine.attach(avAudioUnit)
        let audioUnit = LoadedAudioUnit(avAudioUnit.auAudioUnit)
        if let state = slot.state {
            audioUnit.fullState = state
        }
        remove(at: position)
        chain[position] = Node(avAudioUnit: avAudioUnit, audioUnit: audioUnit)
        return .success(audioUnit)
    }

    private func remove(at position: Int) {
        guard let node = chain.removeValue(forKey: position) else { return }
        engine.detach(node.avAudioUnit)
    }
}

private extension AudioUnitComponent {
    var componentDescription: AudioComponentDescription {
        AudioComponentDescription(
            componentType: id.type,
            componentSubType: id.subType,
            componentManufacturer: id.manufacturer,
            componentFlags: 0,
            componentFlagsMask: 0
        )
    }
}

private extension AVAudioUnit {
    var acceptsAudioInput: Bool {
        let type = audioComponentDescription.componentType
        return type == kAudioUnitType_Effect || type == kAudioUnitType_MusicEffect
    }

    var inputChannelCount: AVAudioChannelCount {
        auAudioUnit.inputBusses[0].format.channelCount
    }

    var outputChannelCount: AVAudioChannelCount {
        auAudioUnit.outputBusses[0].format.channelCount
    }

    /// Whether the unit declares `inputChannelCount` input channels next to its current output.
    /// A unit that declares nothing takes any count, as long as input and output match.
    func accepts(inputChannelCount: AVAudioChannelCount) -> Bool {
        let input = Int(inputChannelCount)
        let output = Int(outputChannelCount)
        let counts = auAudioUnit.channelCapabilities?.map(\.intValue) ?? []
        guard !counts.isEmpty else { return input == output }
        return stride(from: 0, to: counts.count - 1, by: 2).contains { index in
            let (declaredInput, declaredOutput) = (counts[index], counts[index + 1])
            if declaredInput == -1, declaredOutput == -1 {
                return input == output
            }
            return declaredInput.allowsChannelCount(input) && declaredOutput.allowsChannelCount(output)
        }
    }
}

private extension Int {
    /// A declared `channelCapabilities` count: -1 and -2 allow any count, below -2 sets a maximum.
    func allowsChannelCount(_ count: Int) -> Bool {
        self < -2 ? count <= -self : self < 0 || self == count
    }
}

private extension AVAudioEngineType {
    func format(channelCount: AVAudioChannelCount) -> AVAudioFormat? {
        AVAudioFormat(standardFormatWithSampleRate: hardwareOutputFormat.sampleRate, channels: channelCount)
    }
}

private extension Dictionary where Key: Comparable {
    var orderedValues: [Value] {
        sorted { $0.key < $1.key }.map(\.value)
    }
}
