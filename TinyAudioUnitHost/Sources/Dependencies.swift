//
//  Dependencies.swift
//  TinyAudioUnitHost
//
//  Created by Alex Shubin on 19.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioSettingsKit
import AudioUnitsKit
import EngineKit
import PresetKit
import SwiftUI

struct Dependencies: Sendable {
    let audioSettings: AudioSettingsKit.Dependencies
    let audioUnits: AudioUnitsKit.Dependencies
    let engine: EngineKit.Dependencies
    let presets: PresetKit.Dependencies

    static let live: Dependencies = {
        Dependencies(audioSettings: .live, audioUnits: .live, engine: .live, presets: .live)
    }()

    @MainActor func makeHostViewModel() -> HostViewModelType {
        HostViewModel(
            engine: engine.engine,
            library: audioUnits.audioUnitComponentsLibrary,
            presetProvider: presets.presetProvider
        )
    }

    @MainActor func makeSettingsViewModel() -> SettingsViewModelType {
        SettingsViewModel(
            audioSettings: audioSettings.audioSettingsProvider,
            targetSettings: audioSettings.targetSettingsProvider,
            devicesProvider: audioSettings.devicesProvider,
            engine: engine.engine
        )
    }
}

// MARK: - Environment

extension EnvironmentValues {
    @Entry var dependencies: Dependencies = .live
}
