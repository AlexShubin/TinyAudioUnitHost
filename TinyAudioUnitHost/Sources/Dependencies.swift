//
//  Dependencies.swift
//  TinyAudioUnitHost
//
//  Created by Alex Shubin on 19.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import StorageKit
import SwiftUI

struct Dependencies: Sendable {
    let audioSettingsStore: AudioSettingsStoreType
    let devicesProvider: AudioDevicesProviderType
    let audioUnitEngineManager: AudioUnitEngineManagerType
    let audioUnitComponentsLibrary: AudioUnitComponentsLibraryType

    static let live: Dependencies = {
        let storage = StorageKit.Dependencies.live
        let engine = AudioUnitEngine(coreMidiManager: CoreMidiManager())
        let devicesProvider = AudioDevicesProvider()
        let aggregateDeviceManager = AggregateDeviceManager(devicesProvider: devicesProvider)
        return Dependencies(
            audioSettingsStore: storage.audioSettingsStore,
            devicesProvider: devicesProvider,
            audioUnitEngineManager: AudioUnitEngineManager(
                engine: engine,
                settingsStore: storage.audioSettingsStore,
                aggregateDeviceManager: aggregateDeviceManager
            ),
            audioUnitComponentsLibrary: AudioUnitComponentsLibrary()
        )
    }()

    @MainActor func makeHostViewModel() -> HostViewModelType {
        HostViewModel(
            engine: audioUnitEngineManager,
            library: audioUnitComponentsLibrary
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
