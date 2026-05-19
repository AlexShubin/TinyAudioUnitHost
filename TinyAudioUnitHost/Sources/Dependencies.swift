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
import PurchasesKit
import SwiftUI

struct Dependencies: Sendable {
    let audioSettings: AudioSettingsKit.Dependencies
    let audioUnits: AudioUnitsKit.Dependencies
    let engine: EngineKit.Dependencies
    let presets: PresetKit.Dependencies
    let purchases: PurchasesKit.Dependencies

    static let live: Dependencies = {
        Dependencies(
            audioSettings: .live,
            audioUnits: .live,
            engine: .live,
            presets: .live,
            purchases: .live
        )
    }()

    @MainActor func makeHostViewModel() -> HostViewModelType {
        HostViewModel(
            library: audioUnits.audioUnitComponentsLibrary,
            engine: engine.engine,
            presetProvider: presets.presetProvider,
            setupChecker: audioSettings.setupChecker,
            presetNameValidator: presets.presetNameValidator,
            purchasesService: purchases.purchasesService
        )
    }

    @MainActor func makeSettingsViewModel() -> SettingsViewModelType {
        SettingsViewModel(
            audioSettings: audioSettings.audioSettingsProvider,
            targetSettings: audioSettings.targetSettingsProvider,
            devicesProvider: audioSettings.devicesProvider,
            engine: engine.engine,
            setupChecker: audioSettings.setupChecker
        )
    }

    @MainActor func makePurchasesViewModel() -> PurchasesViewModelType {
        PurchasesViewModel(purchasesService: purchases.purchasesService)
    }
}

// MARK: - Environment

extension EnvironmentValues {
    @Entry var dependencies: Dependencies = .live
}
