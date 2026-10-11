//
//  AppCommandsPresenter.swift
//  TinyAudioUnitHost
//
//  Created by Alex Shubin on 20.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import Observation

@MainActor @Observable
final class AppCommandsPresenter {
    var isSaveButtonDisabled: Bool { session.activePresetName == nil || !session.canSavePreset }
    var isRestoreButtonDisabled: Bool { session.activePresetName == nil || session.isBusy }
    var isSaveAsButtonDisabled: Bool { !session.canSavePreset }

    private let session: SessionModelType
    private let saveAsCommand: CommandType

    init(session: SessionModelType, saveAsCommand: CommandType) {
        self.session = session
        self.saveAsCommand = saveAsCommand
    }

    func savePreset() {
        session.saveCurrentPreset()
    }

    func restorePreset() async {
        await session.restoreActivePreset()
    }

    func saveAsPreset() {
        saveAsCommand.execute()
    }
}
