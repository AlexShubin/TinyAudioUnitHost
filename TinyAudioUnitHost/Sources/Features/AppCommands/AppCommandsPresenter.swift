//
//  AppCommandsPresenter.swift
//  TinyAudioUnitHost
//
//  Created by Alex Shubin on 20.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import ChannelStripKit
import Observation
import PresetKit

@MainActor @Observable
final class AppCommandsPresenter {
    var isSaveButtonDisabled: Bool { presets.activeName == nil || !channelStrip.isSavable }
    var isRestoreButtonDisabled: Bool { presets.activeName == nil || channelStrip.isBusy }
    var isSaveAsButtonDisabled: Bool { !channelStrip.isSavable }

    private let channelStrip: ChannelStripModelType
    private let presets: PresetsModelType
    private let presetsNavigation: PresetsNavigationModelType

    init(
        channelStrip: ChannelStripModelType,
        presets: PresetsModelType,
        presetsNavigation: PresetsNavigationModelType
    ) {
        self.channelStrip = channelStrip
        self.presets = presets
        self.presetsNavigation = presetsNavigation
    }

    func savePreset() {
        guard let preset = channelStrip.preset else { return }
        presets.saveCurrent(preset: preset)
    }

    func restorePreset() async {
        await presets.restoreActive()
    }

    func saveAsPreset() {
        presetsNavigation.presentedNameDialogMode = .saveAs
    }
}
