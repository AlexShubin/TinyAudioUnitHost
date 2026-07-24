//
//  AppCommands.swift
//  TinyAudioUnitHost
//
//  Created by Alex Shubin on 15.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import SwiftUI

struct AppCommands: Commands {
    @State var viewModel: AppCommandsViewModelType

    var body: some Commands {
        CommandGroup(replacing: .saveItem) {
            Button("Save Preset") {
                Task { await viewModel.accept(action: .save) }
            }
            .keyboardShortcut("s", modifiers: .command)
            .disabled(viewModel.isSaveButtonDisabled)

            Button("Save Preset As…") {
                Task { await viewModel.accept(action: .saveAs) }
            }
            .keyboardShortcut("s", modifiers: [.command, .shift])
            .disabled(viewModel.isSaveAsButtonDisabled)

            Button("Restore Preset") {
                Task { await viewModel.accept(action: .restore) }
            }
            .keyboardShortcut("r", modifiers: .command)
            .disabled(viewModel.isRestoreButtonDisabled)
        }
    }
}
