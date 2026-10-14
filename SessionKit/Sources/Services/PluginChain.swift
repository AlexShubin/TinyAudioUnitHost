//
//  PluginChain.swift
//  SessionKit
//
//  Created by Alex Shubin on 19.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioUnitsKit
import AVFoundation
import OSLog

public enum PluginChainLoadError: Error, Sendable, Equatable {
    case audioUnitInstantiationFailed
}

public protocol PluginChainType: Sendable {
    func load(_ slot: PluginChainSlot, at position: Int) async throws(PluginChainLoadError) -> LoadedAudioUnit
    func load(_ slots: [PluginChainSlot?]) async -> [Result<LoadedAudioUnit, PluginChainLoadError>?]
    func unload(at position: Int) async
    func reconnect() async
}

final actor PluginChain: PluginChainType {
    private struct Node {
        let avAudioUnit: AVAudioUnit
        let audioUnit: LoadedAudioUnit
    }

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "PluginChain")

    private let engine: AVAudioEngineType
    private let avAudioUnitFactory: AVAudioUnitFactoryType
    private let hardwareConnector: HardwareConnectorType
    private let midiManager: MidiManagerType
    private var chain: [Int: Node] = [:]

    init(
        engine: AVAudioEngineType,
        avAudioUnitFactory: AVAudioUnitFactoryType,
        hardwareConnector: HardwareConnectorType,
        midiManager: MidiManagerType
    ) {
        self.engine = engine
        self.avAudioUnitFactory = avAudioUnitFactory
        self.hardwareConnector = hardwareConnector
        self.midiManager = midiManager
    }

    func load(_ slot: PluginChainSlot, at position: Int) async throws(PluginChainLoadError) -> LoadedAudioUnit {
        await stop()
        remove(at: position)
        let result = await insert(slot, at: position)
        await start()
        return try result.get()
    }

    func load(_ slots: [PluginChainSlot?]) async -> [Result<LoadedAudioUnit, PluginChainLoadError>?] {
        await stop()
        for position in chain.keys {
            remove(at: position)
        }
        let results = await withTaskGroup(of: (Int, Result<LoadedAudioUnit, PluginChainLoadError>).self) { group in
            for (position, slot) in slots.enumerated() {
                guard let slot else { continue }
                group.addTask { (position, await self.insert(slot, at: position)) }
            }
            var results = [Result<LoadedAudioUnit, PluginChainLoadError>?](repeating: nil, count: slots.count)
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
        hardwareConnector.disconnect(in: engine)
        await midiManager.teardownMIDI()
    }

    private func start() async {
        // Another operation may have started the engine while this one was suspended.
        await stop()
        let nodes = chain.orderedValues
        guard let first = nodes.first, let last = nodes.last,
              await hardwareConnector.connect(first: first.avAudioUnit, last: last.avAudioUnit, in: engine) else { return }
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
        await midiManager.setupMIDI(for: first.audioUnit)
    }

    private func insert(_ slot: PluginChainSlot, at position: Int) async -> Result<LoadedAudioUnit, PluginChainLoadError> {
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
