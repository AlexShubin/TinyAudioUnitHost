//
//  AudioUnitEngineManager.swift
//  TinyAudioUnitHost
//
//  Created by Alex Shubin on 19.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

enum DeviceBindingIntent: Equatable, Sendable {
    case none
    case direct(AudioDevice)
    case aggregate(input: AudioDevice, output: AudioDevice)
}

protocol AudioUnitEngineManagerType: Sendable {
    func load(component: AudioUnitComponent) async -> LoadedAudioUnit?
    func reconnect() async
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

    func reconnect() async {
        await engine.stop()
        await engine.disconnect()
        await applyConnections()
        await engine.start()
    }

    static func bindingIntent(input: AudioDevice?, output: AudioDevice?) -> DeviceBindingIntent {
        switch (input, output) {
        case (nil, nil):
            return .none
        case let (dev?, nil), let (nil, dev?):
            return .direct(dev)
        case let (inDev?, outDev?) where inDev.id == outDev.id:
            return .direct(inDev)
        case let (inDev?, outDev?):
            return .aggregate(input: inDev, output: outDev)
        }
    }

    private func applyConnections() async {
        let settings = await settingsStore.current()
        let intent = Self.bindingIntent(input: settings.input.device, output: settings.output.device)
        let targetID = await aggregateDeviceManager.resolve(intent)

        // Sub-device list is [input, output]. Input scope keeps its channel
        // indices; output scope is shifted by the input sub-device's output
        // channel count.
        let inputOffset = 0
        let outputOffset: Int = {
            if case .aggregate = intent {
                return settings.input.device?.outputChannels.count ?? 0
            }
            return 0
        }()

        await engine.bindDevice(targetID)

        if let input = settings.input.selectedChannel {
            await engine.connectInputs(channels: input, hardwareOffset: inputOffset)
        }
        if let output = settings.output.selectedChannel {
            await engine.connectOutputs(channels: output, hardwareOffset: outputOffset)
        }
    }
}
