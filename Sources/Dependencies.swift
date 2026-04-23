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
    let audioUnitHostEngine: AudioUnitHostEngineType

    static let live = Dependencies(
        audioSettingsStore: AudioSettingsStore(),
        audioUnitHostEngine: AudioUnitHostEngine(coreMidiManager: CoreMidiManager())
    )

    @MainActor func makeHostViewModel() -> HostViewModelType {
        HostViewModel(
            engine: audioUnitHostEngine,
            library: AudioUnitComponentsLibrary()
        )
    }

    @MainActor func makeSettingsViewModel() -> SettingsViewModelType {
        SettingsViewModel(
            devicesProvider: AudioInputDevicesProvider(),
            settingsStore: audioSettingsStore,
            engine: audioUnitHostEngine
        )
    }
}

// MARK: - Environment

extension EnvironmentValues {
    @Entry var dependencies: Dependencies = .live
}
