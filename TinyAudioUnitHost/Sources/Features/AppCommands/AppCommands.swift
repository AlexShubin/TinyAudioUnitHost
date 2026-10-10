//
//  AppCommands.swift
//  TinyAudioUnitHost
//
//  Created by Alex Shubin on 15.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import SwiftUI

struct AppCommands: Commands {
    let presenter: AppCommandsPresenter

    var body: some Commands {
        CommandGroup(replacing: .saveItem) {
            Button("Save Preset") {
                presenter.savePreset()
            }
            .keyboardShortcut("s", modifiers: .command)
            .disabled(presenter.isSaveButtonDisabled)

            Button("Save Preset As…") {
                presenter.saveAsPreset()
            }
            .keyboardShortcut("s", modifiers: [.command, .shift])
            .disabled(presenter.isSaveAsButtonDisabled)

            Button("Restore Preset") {
                Task { await presenter.restorePreset() }
            }
            .keyboardShortcut("r", modifiers: .command)
            .disabled(presenter.isRestoreButtonDisabled)
        }
    }
}
