//
//  AudioUnitEngineManager.swift
//  TinyAudioUnitHost
//
//  Created by Alex Shubin on 19.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import CoreAudio

enum DeviceBindingIntent: Equatable, Sendable {
    case none
    case direct(AudioDeviceID)
    case aggregate(input: AudioDeviceID, output: AudioDeviceID)
}

protocol AudioUnitEngineManagerType: Sendable {
    func load(component: AudioUnitComponent) async -> LoadedAudioUnit?
    func reconnect() async
}

final actor AudioUnitEngineManager: AudioUnitEngineManagerType {
    private let engine: AudioUnitEngineType
    private let settingsStore: AudioSettingsStoreType
    private let aggregateFactory: AggregateDeviceFactoryType

    private var currentAggregateID: AudioDeviceID?

    init(
        engine: AudioUnitEngineType,
        settingsStore: AudioSettingsStoreType,
        aggregateFactory: AggregateDeviceFactoryType
    ) {
        self.engine = engine
        self.settingsStore = settingsStore
        self.aggregateFactory = aggregateFactory
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
            return .direct(dev.id)
        case let (inDev?, outDev?) where inDev.id == outDev.id:
            return .direct(inDev.id)
        case let (inDev?, outDev?):
            return .aggregate(input: inDev.id, output: outDev.id)
        }
    }

    private func applyConnections() async {
        let settings = await settingsStore.current()

        if let previous = currentAggregateID {
            aggregateFactory.destroy(previous)
            currentAggregateID = nil
        }

        let intent = Self.bindingIntent(input: settings.input.device, output: settings.output.device)
        let targetID: AudioDeviceID?
        // Sub-device list is [input, output]. Input scope keeps its channel
        // indices; output scope is shifted by the input sub-device's output
        // channel count.
        let inputOffset = 0
        var outputOffset = 0
        switch intent {
        case .none:
            targetID = nil
        case .direct(let id):
            targetID = id
        case .aggregate(let inputID, let outputID):
            let id = aggregateFactory.create(inputDeviceID: inputID, outputDeviceID: outputID)
            currentAggregateID = id
            targetID = id
            outputOffset = settings.input.device?.outputChannels.count ?? 0
        }

        await engine.bindDevice(targetID)

        if let input = settings.input.selectedChannel {
            await engine.connectInputs(channels: input, hardwareOffset: inputOffset)
        }
        if let output = settings.output.selectedChannel {
            await engine.connectOutputs(channels: output, hardwareOffset: outputOffset)
        }
    }
}
