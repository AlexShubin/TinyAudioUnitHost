//
//  PresetsPresenter.swift
//  TinyAudioUnitHost
//
//  Created by Alex Shubin on 19.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import ChannelStripKit
import Observation
import PresetKit

@MainActor @Observable
final class PresetsPresenter {
    var names: [String] { presets.names }
    var activeName: String? { presets.activeName }
    var isInteractionDisabled: Bool { channelStrip.isBusy }
    var isSaveAsButtonDisabled: Bool { !channelStrip.isSavable }

    var presentedNameDialogMode: PresetNameDialogMode? {
        get { presetsNavigation.presentedNameDialogMode }
        set { presetsNavigation.presentedNameDialogMode = newValue }
    }

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

    func select(name: String) async {
        await presets.select(name: name)
    }

    func rename(name: String) {
        presetsNavigation.presentedNameDialogMode = .rename(currentName: name)
    }

    func delete(name: String) {
        presets.delete(name: name)
    }

    func saveAs() {
        presetsNavigation.presentedNameDialogMode = .saveAs
    }
}
