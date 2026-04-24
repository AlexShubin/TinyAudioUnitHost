//
//  AudioUnitEngineManager.swift
//  TinyAudioUnitHost
//
//  Created by Alex Shubin on 19.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

protocol AudioUnitEngineManagerType: Sendable {
    func load(component: AudioUnitComponent) async -> LoadedAudioUnit?
    func reconnect() async
}

final class AudioUnitEngineManager: AudioUnitEngineManagerType {
    private let engine: AudioUnitEngineType
    private let settingsStore: AudioSettingsStoreType

    init(engine: AudioUnitEngineType, settingsStore: AudioSettingsStoreType) {
        self.engine = engine
        self.settingsStore = settingsStore
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

    private func applyConnections() async {
        let settings = await settingsStore.current()
        if let inputDevice = settings.input.device {
            await engine.setInputDevice(inputDevice)
        }
        if let outputDevice = settings.output.device {
            await engine.setOutputDevice(outputDevice)
        }
        if let input = settings.input.selectedChannel {
            await engine.connectInputs(channels: input)
        }
        if let output = settings.output.selectedChannel {
            await engine.connectOutputs(channels: output)
        }
    }
}
