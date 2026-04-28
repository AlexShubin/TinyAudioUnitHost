//
//  AudioUnitEngineManager.swift
//  EngineKit
//
//  Created by Alex Shubin on 19.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import Common
import StorageKit

public protocol AudioUnitEngineManagerType: Sendable {
    func load(component: AudioUnitComponent) async -> LoadedAudioUnit?
    func reload() async
}

final actor AudioUnitEngineManager: AudioUnitEngineManagerType {
    private let engine: AudioUnitEngineType
    private let settingsStore: AudioSettingsStoreType
    private let aggregateDeviceManager: AggregateDeviceManagerType

    init(
        engine: AudioUnitEngineType,
        settingsStore: AudioSettingsStoreType,
        aggregateDeviceManager: AggregateDeviceManagerType
    ) {
        self.engine = engine
        self.settingsStore = settingsStore
        self.aggregateDeviceManager = aggregateDeviceManager
    }

    func load(component: AudioUnitComponent) async -> LoadedAudioUnit? {
        await engine.teardownMidi()
        await engine.stop()
        await engine.disconnect()
        await engine.unloadAudioUnit()

        guard let loaded = await engine.load(audioUnit: component) else { return nil }

        await applyConnections()
        await engine.connectMidi()
        await engine.start()
        return loaded
    }

    func reload() async {
        await engine.stop()
        await engine.disconnect()
        await applyConnections()
        await engine.start()
    }

    private func applyConnections() async {
        let settings = await settingsStore.current()
        let target = await aggregateDeviceManager.resolveTarget()

        await engine.bindDevice(target?.device.id)
        if let frames = settings.bufferSize, let deviceID = target?.device.id {
            await engine.setBufferSize(frames, deviceID: deviceID)
        }

        if let input = settings.input.selectedChannel {
            await engine.connectInputs(channels: input, hardwareOffset: target?.inputOffset ?? 0)
        }
        if let output = settings.output.selectedChannel {
            await engine.connectOutputs(channels: output, hardwareOffset: target?.outputOffset ?? 0)
        }
    }
}
