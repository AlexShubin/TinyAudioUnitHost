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
    let session: SessionManagerType

    static let live: Dependencies = {
        let engine = EngineKit.Dependencies.live
        let presets = PresetKit.Dependencies.live
        let purchases = PurchasesKit.Dependencies.live
        return Dependencies(
            audioSettings: .live,
            audioUnits: .live,
            engine: engine,
            presets: presets,
            purchases: purchases,
            session: SessionManager(
                engine: engine.engine,
                presetProvider: presets.presetProvider,
                purchasesService: purchases.purchasesService
            )
        )
    }()

    @MainActor func makeHostViewModel() -> HostViewModelType {
        HostViewModel(
            library: audioUnits.audioUnitComponentsLibrary,
            session: session,
            setupChecker: audioSettings.setupChecker
        )
    }

    @MainActor func makePresetsSidebarViewModel() -> PresetsSidebarViewModelType {
        PresetsSidebarViewModel(session: session)
    }

    @MainActor func makeHostCommandsViewModel() -> HostCommandsViewModelType {
        HostCommandsViewModel(session: session)
    }

    @MainActor func makePresetNameDialogViewModel(
        mode: PresetNameDialogState.Mode,
        initialName: String
    ) -> PresetNameDialogViewModelType {
        PresetNameDialogViewModel(
            mode: mode,
            initialName: initialName,
            session: session,
            validator: presets.presetNameValidator
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
