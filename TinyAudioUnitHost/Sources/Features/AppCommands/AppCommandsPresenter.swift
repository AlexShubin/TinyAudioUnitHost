//
//  AppCommandsPresenter.swift
//  TinyAudioUnitHost
//
//  Created by Alex Shubin on 20.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

@MainActor
protocol AppCommandsPresenterType {
    var isSaveButtonDisabled: Bool { get }
    var isRestoreButtonDisabled: Bool { get }
    var isSaveAsButtonDisabled: Bool { get }
    func savePreset()
    func restorePreset() async
    func saveAsPreset()
}

@MainActor
struct AppCommandsPresenter: AppCommandsPresenterType {
    var isSaveButtonDisabled: Bool { session.activeName == nil || !session.content.isLoaded }
    var isRestoreButtonDisabled: Bool { session.activeName == nil || !session.content.isOperable }
    var isSaveAsButtonDisabled: Bool { !session.content.isLoaded }

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
