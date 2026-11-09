//
//  AppCommandsPresenter.swift
//  TinyAudioUnitHost
//
//  Created by Alex Shubin on 20.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import Observation
import ChannelStripKit

@MainActor @Observable
final class AppCommandsPresenter {
    var isSaveButtonDisabled: Bool { session.activePresetName == nil || !session.canSavePreset }
    var isRestoreButtonDisabled: Bool { session.activePresetName == nil || session.isBusy }
    var isSaveAsButtonDisabled: Bool { !session.canSavePreset }

    private let session: ChannelStripModelType
    private let presetsNavigation: PresetsNavigationModelType

    init(session: ChannelStripModelType, presetsNavigation: PresetsNavigationModelType) {
        self.session = session
        self.presetsNavigation = presetsNavigation
    }

    func savePreset() {
        session.saveCurrentPreset()
    }

    func restorePreset() async {
        await session.restoreActivePreset()
    }

    func saveAsPreset() {
        presetsNavigation.presentedNameDialogMode = .saveAs
    }
}
