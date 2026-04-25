//
//  Dependencies.swift
//  TinyAudioUnitHost
//
//  Created by Alex Shubin on 19.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import SwiftUI

struct Dependencies: Sendable {
    let audioSettingsStore: AudioSettingsStoreType
    let devicesProvider: AudioDevicesProviderType
    let audioUnitEngineManager: AudioUnitEngineManagerType

    static let live: Dependencies = {
        let settingsStore = AudioSettingsStore()
        let engine = AudioUnitEngine(coreMidiManager: CoreMidiManager())
        let devicesProvider = AudioDevicesProvider()
        let aggregateDeviceManager = AggregateDeviceManager(devicesProvider: devicesProvider)
        return Dependencies(
            audioSettingsStore: settingsStore,
            devicesProvider: devicesProvider,
            audioUnitEngineManager: AudioUnitEngineManager(
                engine: engine,
                settingsStore: settingsStore,
                aggregateDeviceManager: aggregateDeviceManager
            )
        )
    }()

    @MainActor func makeHostViewModel() -> HostViewModelType {
        HostViewModel(
            engine: audioUnitEngineManager,
            library: AudioUnitComponentsLibrary()
        )
    }

    @MainActor func makeSettingsViewModel() -> SettingsViewModelType {
        SettingsViewModel(
            devicesProvider: devicesProvider,
            settingsStore: audioSettingsStore,
            engine: audioUnitEngineManager
        )
    }
}

// MARK: - Environment

extension EnvironmentValues {
    @Entry var dependencies: Dependencies = .live
}
