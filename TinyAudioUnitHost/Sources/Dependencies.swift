//
//  Dependencies.swift
//  TinyAudioUnitHost
//
//  Created by Alex Shubin on 19.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioSettingsKit
import AudioUnitsKit
import PresetKit
import PurchasesKit
import SessionKit
import SwiftUI

@MainActor
struct Dependencies: Sendable {
    let audioSettings: AudioSettingsKit.Dependencies
    let audioUnits: AudioUnitsKit.Dependencies
    let presets: PresetKit.Dependencies
    let purchases: PurchasesKit.Dependencies
    let session: SessionKit.Dependencies
    let audioSettingsObserver: AudioSettingsObserverType
    let presetsNavigation: PresetsNavigationModelType

    static let live: Dependencies = {
        let audioSettings = AudioSettingsKit.Dependencies.live
        let session = SessionKit.Dependencies.live
        return Dependencies(
            audioSettings: audioSettings,
            audioUnits: .live,
            presets: .live,
            purchases: .live,
            session: session,
            audioSettingsObserver: AudioSettingsObserver(
                audioSettings: audioSettings.audioSettingsModel,
                session: session.sessionModel
            ),
            presetsNavigation: PresetsNavigationModel()
        )
    }()

    func makeHostPresenter() -> HostPresenter {
        HostPresenter(
            session: session.sessionModel,
            audioSettings: audioSettings.audioSettingsModel,
            purchases: purchases.purchasesModel
        )
    }

    func makeChannelStripPresenter() -> ChannelStripPresenter {
        ChannelStripPresenter(
            library: audioUnits.audioUnitComponentsLibrary,
            session: session.sessionModel,
            audioSettings: audioSettings.audioSettingsModel,
            purchases: purchases.purchasesModel
        )
    }

    func makePresetsPresenter() -> PresetsPresenter {
        PresetsPresenter(
            session: session.sessionModel,
            presetsNavigation: presetsNavigation
        )
    }

    func makeAppCommandsPresenter() -> AppCommandsPresenter {
        AppCommandsPresenter(
            session: session.sessionModel,
            presetsNavigation: presetsNavigation
        )
    }

    func makePresetNameDialogPresenter(mode: PresetNameDialogMode) -> PresetNameDialogPresenter {
        PresetNameDialogPresenter(
            mode: mode,
            session: session.sessionModel,
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
