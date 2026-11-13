//
//  Dependencies.swift
//  TinyAudioUnitHost
//
//  Created by Alex Shubin on 19.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioSettingsKit
import AudioUnitsKit
import ChannelStripKit
import PresetKit
import PurchasesKit
import SwiftUI

@MainActor
struct Dependencies: Sendable {
    let audioSettings: AudioSettingsKit.Dependencies
    let audioUnits: AudioUnitsKit.Dependencies
    let channelStrip: ChannelStripKit.Dependencies
    let presets: PresetKit.Dependencies
    let purchases: PurchasesKit.Dependencies
    let audioSettingsObserver: AudioSettingsObserver
    let presetsObserver: PresetsObserver
    let presetsNavigation: PresetsNavigationModelType

    static let live: Dependencies = {
        let audioSettings = AudioSettingsKit.Dependencies.live
        let channelStrip = ChannelStripKit.Dependencies.live
        let presets = PresetKit.Dependencies.live
        return Dependencies(
            audioSettings: audioSettings,
            audioUnits: .live,
            channelStrip: channelStrip,
            presets: presets,
            purchases: .live,
            audioSettingsObserver: AudioSettingsObserver(
                audioSettings: audioSettings.audioSettingsModel,
                channelStrip: channelStrip.channelStripModel
            ),
            presetsObserver: PresetsObserver(
                presets: presets.presetsModel,
                channelStrip: channelStrip.channelStripModel
            ),
            presetsNavigation: PresetsNavigationModel()
        )
    }()

    func makeHostPresenter() -> HostPresenter {
        HostPresenter(
            channelStrip: channelStrip.channelStripModel,
            presets: presets.presetsModel,
            audioSettings: audioSettings.audioSettingsModel,
            purchases: purchases.purchasesModel
        )
    }

    func makeChannelStripPresenter() -> ChannelStripPresenter {
        ChannelStripPresenter(
            library: audioUnits.audioUnitComponentsLibrary,
            channelStrip: channelStrip.channelStripModel,
            audioSettings: audioSettings.audioSettingsModel,
            purchases: purchases.purchasesModel
        )
    }

    func makePresetsPresenter() -> PresetsPresenter {
        PresetsPresenter(
            channelStrip: channelStrip.channelStripModel,
            presets: presets.presetsModel,
            presetsNavigation: presetsNavigation
        )
    }

    func makeAppCommandsPresenter() -> AppCommandsPresenter {
        AppCommandsPresenter(
            channelStrip: channelStrip.channelStripModel,
            presets: presets.presetsModel,
            presetsNavigation: presetsNavigation
        )
    }

    func makePresetNameDialogPresenter(mode: PresetNameDialogMode) -> PresetNameDialogPresenter {
        PresetNameDialogPresenter(
            mode: mode,
            channelStrip: channelStrip.channelStripModel,
            presets: presets.presetsModel,
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
