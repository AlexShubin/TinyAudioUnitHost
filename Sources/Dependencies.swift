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
    let audioUnitEngineManager: AudioUnitEngineManagerType

    static let live = Dependencies(
        audioSettingsStore: AudioSettingsStore(),
        audioUnitEngineManager: AudioUnitEngineManager(coreMidiManager: CoreMidiManager())
    )

    @MainActor func makeHostViewModel() -> HostViewModelType {
        HostViewModel(
            engine: audioUnitEngineManager,
            library: AudioUnitComponentsLibrary()
        )
    }

    @MainActor func makeSettingsViewModel() -> SettingsViewModelType {
        SettingsViewModel(
            devicesProvider: AudioDevicesProvider(),
            settingsStore: audioSettingsStore,
            engine: audioUnitEngineManager
        )
    }
}

// MARK: - Environment

extension EnvironmentValues {
    @Entry var dependencies: Dependencies = .live
}
