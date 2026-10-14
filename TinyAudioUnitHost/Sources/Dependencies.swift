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

@MainActor
struct Dependencies: Sendable {
    let audioSettings: AudioSettingsKit.Dependencies
    let audioUnits: AudioUnitsKit.Dependencies
    let engine: EngineKit.Dependencies
    let presets: PresetKit.Dependencies
    let purchases: PurchasesKit.Dependencies
    let session: SessionModelType
    let audioSettingsObserver: AudioSettingsObserverType
    let presetsNavigation: PresetsNavigationModelType

    static let live: Dependencies = {
        let audioSettings = AudioSettingsKit.Dependencies.live
        let engine = EngineKit.Dependencies.live
        let presets = PresetKit.Dependencies.live
        let purchases = PurchasesKit.Dependencies.live
        let session = SessionModel(
            engine: engine.engine,
            presetProvider: presets.presetProvider
        )
        return Dependencies(
            audioSettings: audioSettings,
            audioUnits: .live,
            engine: engine,
            presets: presets,
            purchases: purchases,
            session: session,
            audioSettingsObserver: AudioSettingsObserver(
                audioSettings: audioSettings.audioSettingsModel,
                engine: engine.engine,
                midiManager: engine.midiManager
            ),
            presetsNavigation: PresetsNavigationModel()
        )
    }()

    func makeHostPresenter() -> HostPresenter {
        HostPresenter(
            session: session,
            audioSettings: audioSettings.audioSettingsModel,
            purchases: purchases.purchasesModel
        )
    }

    func makeChannelStripPresenter() -> ChannelStripPresenter {
        ChannelStripPresenter(
            library: audioUnits.audioUnitComponentsLibrary,
            session: session,
            audioSettings: audioSettings.audioSettingsModel,
            purchases: purchases.purchasesModel
        )
    }

    func makePresetsPresenter() -> PresetsPresenter {
        PresetsPresenter(
            session: session,
            presetsNavigation: presetsNavigation
        )
    }

    func makeAppCommandsPresenter() -> AppCommandsPresenter {
        AppCommandsPresenter(
            session: session,
            presetsNavigation: presetsNavigation
        )
    }

    func makePresetNameDialogPresenter(mode: PresetNameDialogMode) -> PresetNameDialogPresenter {
        PresetNameDialogPresenter(
            mode: mode,
            session: session,
            validator: presets.presetNameValidator
        )
    }

    func makeSettingsPresenter() -> SettingsPresenter {
        SettingsPresenter(audioSettings: audioSettings.audioSettingsModel)
    }

    func makePurchasesPresenter() -> PurchasesPresenter {
        PurchasesPresenter(purchases: purchases.purchasesModel)
    }
}

// MARK: - Environment

extension EnvironmentValues {
    @Entry var dependencies: Dependencies = MainActor.assumeIsolated { .live }
}
