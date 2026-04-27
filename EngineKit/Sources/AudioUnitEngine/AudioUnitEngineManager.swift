//
//  AudioUnitEngineManager.swift
//  EngineKit
//
//  Created by Alex Shubin on 19.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import Common

public protocol AudioUnitEngineManagerType: Sendable {
    func load(
        component: AudioUnitComponent,
        target: TargetAudioDevice?,
        input: SelectedChannel?,
        output: SelectedChannel?
    ) async -> LoadedAudioUnit?
    func apply(
        target: TargetAudioDevice?,
        input: SelectedChannel?,
        output: SelectedChannel?
    ) async
}

final actor AudioUnitEngineManager: AudioUnitEngineManagerType {
    private let engine: AudioUnitEngineType

    init(engine: AudioUnitEngineType) {
        self.engine = engine
    }

    func load(
        component: AudioUnitComponent,
        target: TargetAudioDevice?,
        input: SelectedChannel?,
        output: SelectedChannel?
    ) async -> LoadedAudioUnit? {
        await engine.teardownMidi()
        await engine.stop()
        await engine.disconnect()
        await engine.unloadAudioUnit()

        guard let loaded = await engine.load(audioUnit: component) else { return nil }

        await applyConnections(target: target, input: input, output: output)
        await engine.connectMidi()
        await engine.start()
        return loaded
    }

    func apply(
        target: TargetAudioDevice?,
        input: SelectedChannel?,
        output: SelectedChannel?
    ) async {
        await engine.stop()
        await engine.disconnect()
        await applyConnections(target: target, input: input, output: output)
        await engine.start()
    }

    private func applyConnections(
        target: TargetAudioDevice?,
        input: SelectedChannel?,
        output: SelectedChannel?
    ) async {
        await engine.bindDevice(target?.device.id)

        if let input {
            await engine.connectInputs(channels: input, hardwareOffset: target?.inputOffset ?? 0)
        }
        if let output {
            await engine.connectOutputs(channels: output, hardwareOffset: target?.outputOffset ?? 0)
        }
    }
}
