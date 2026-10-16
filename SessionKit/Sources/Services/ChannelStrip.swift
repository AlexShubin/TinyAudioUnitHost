//
//  ChannelStrip.swift
//  SessionKit
//
//  Created by Alex Shubin on 19.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioSettingsKit
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
    private let audioSettings: AudioSettingsModelType
    private var chain: [Int: Node] = [:]

    init(
        engine: AVAudioEngineType,
        avAudioUnitFactory: AVAudioUnitFactoryType,
        audioConnector: AudioConnectorType,
        midiConnector: MidiConnectorType,
        audioSettings: AudioSettingsModelType
    ) {
        self.engine = engine
        self.avAudioUnitFactory = avAudioUnitFactory
        self.audioConnector = audioConnector
        self.midiConnector = midiConnector
        self.audioSettings = audioSettings
    }

    func load(_ slot: ChannelStripSlot, at position: Int) async throws(ChannelStripLoadError) -> LoadedAudioUnit {
        await stop()
        remove(at: position)
        let result = await insert(slot, at: position)
        await start()
        return try result.get()
    }

    func load(_ slots: [ChannelStripSlot?]) async -> [Result<LoadedAudioUnit, ChannelStripLoadError>?] {
        await stop()
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
        await start()
        return results
    }

    func unload(at position: Int) async {
        await stop()
        remove(at: position)
        await start()
    }

    func reconnect() async {
        guard !chain.isEmpty else { return }
        await start()
    }

    private func stop() async {
        engine.stop()
        audioConnector.disconnect(in: engine)
        await midiConnector.disconnect()
    }

    private func start() async {
        // Another operation may have started the engine while this one was suspended.
        await stop()
        let nodes = chain.orderedValues
        guard let first = nodes.first, let last = nodes.last,
              await audioSettings.setup == .met,
              let device = await audioSettings.targetDevice else { return }
        let settings = SessionHardwareSettings(await audioSettings.settings, targetDevice: device)
        guard audioConnector.connect(first: first.avAudioUnit, last: last.avAudioUnit, to: settings.audio, in: engine) else { return }
        for (source, destination) in zip(nodes, nodes.dropFirst()) {
            let format = AVAudioFormat(
                standardFormatWithSampleRate: engine.hardwareOutputFormat.sampleRate,
                channels: source.avAudioUnit.auAudioUnit.outputBusses[0].format.channelCount
            )
            engine.connect(source.avAudioUnit, to: destination.avAudioUnit, format: format)
        }
        do {
            try engine.start()
        } catch {
            logger.warning("Engine start failed: \(String(describing: error), privacy: .public)")
        }
        await midiConnector.connect(first.audioUnit, settings: settings.midi)
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

private extension Dictionary where Key: Comparable {
    var orderedValues: [Value] {
        sorted { $0.key < $1.key }.map(\.value)
    }
}
