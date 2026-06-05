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
    let eventBus: SessionEventBusType

    static let live: Dependencies = {
        let audioSettings = AudioSettingsKit.Dependencies.live
        let engine = EngineKit.Dependencies.live
        let presets = PresetKit.Dependencies.live
        let purchases = PurchasesKit.Dependencies.live
        let eventBus = SessionEventBus()
        return Dependencies(
            audioSettings: audioSettings,
            audioUnits: .live,
            engine: engine,
            presets: presets,
            purchases: purchases,
            session: SessionManager(
                engine: engine.engine,
                presetProvider: presets.presetProvider,
                setupChecker: audioSettings.setupChecker,
                eventBus: eventBus
            ),
            eventBus: eventBus
        )
    }()

    @MainActor func makeHostViewModel() -> HostViewModelType {
        HostViewModel(
            library: audioUnits.audioUnitComponentsLibrary,
            session: session,
            purchasesService: purchases.purchasesService,
            eventBus: eventBus
        )
    }

    @MainActor func makePresetsViewModel() -> PresetsViewModelType {
        PresetsViewModel(
            session: session,
            purchasesService: purchases.purchasesService,
            eventBus: eventBus
        )
    }

    @MainActor func makeAppCommandsViewModel() -> AppCommandsViewModelType {
        AppCommandsViewModel(
            session: session,
            eventBus: eventBus
        )
    }

    @MainActor func makePresetNameDialogViewModel(
        mode: PresetNameDialogMode
    ) -> PresetNameDialogViewModelType {
        PresetNameDialogViewModel(
            mode: mode,
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

    @MainActor func makeMainWindowViewModel() -> MainWindowViewModelType {
        MainWindowViewModel(
            midiManager: engine.midiManager,
            engineReloader: engine.engineReloader,
            setupRefresher: audioSettings.setupRefresher,
            purchasesService: purchases.purchasesService
        )
    }
}

// MARK: - Environment

extension EnvironmentValues {
    @Entry var dependencies: Dependencies = .live
}
