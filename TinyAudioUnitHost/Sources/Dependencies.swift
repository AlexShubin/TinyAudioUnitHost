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
    let setupChecker: SetupCheckerType

    static let live: Dependencies = {
        let presets = PresetKit.Dependencies.live
        let engine = EngineKit.Dependencies.live
        let audioSettings = AudioSettingsKit.Dependencies.live
        return Dependencies(
            audioSettings: audioSettings,
            audioUnits: .live,
            engine: engine,
            presets: presets,
            sessionManager: SessionManager(
                presetProvider: presets.presetProvider,
                engine: engine.engine
            ),
            setupChecker: SetupChecker(
                targetSettingsProvider: audioSettings.targetSettingsProvider
            )
        )
    }()

    @MainActor func makeHostViewModel() -> HostViewModelType {
        HostViewModel(
            library: audioUnits.audioUnitComponentsLibrary,
            sessionManager: sessionManager,
            setupChecker: setupChecker
        )
    }

    @MainActor func makeSettingsViewModel() -> SettingsViewModelType {
        SettingsViewModel(
            audioSettings: audioSettings.audioSettingsProvider,
            targetSettings: audioSettings.targetSettingsProvider,
            devicesProvider: audioSettings.devicesProvider,
            engine: engine.engine,
            setupChecker: setupChecker
        )
    }
}

// MARK: - Environment

extension EnvironmentValues {
    @Entry var dependencies: Dependencies = .live
}
