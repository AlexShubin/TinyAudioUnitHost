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
    let sessionManager: SessionManagerType

    static let live: Dependencies = {
        let presets = PresetKit.Dependencies.live
        let engine = EngineKit.Dependencies.live
        return Dependencies(
            audioSettings: .live,
            audioUnits: .live,
            engine: engine,
            presets: presets,
            sessionManager: SessionManager(
                presetProvider: presets.presetProvider,
                engine: engine.engine
            )
        )
    }()

    @MainActor func makeHostViewModel() -> HostViewModelType {
        HostViewModel(
            library: audioUnits.audioUnitComponentsLibrary,
            sessionManager: sessionManager
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
