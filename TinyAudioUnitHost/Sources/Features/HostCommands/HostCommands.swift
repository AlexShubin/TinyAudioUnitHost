//
//  HostCommands.swift
//  TinyAudioUnitHost
//
//  Created by Alex Shubin on 15.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import SwiftUI

struct HostCommands: Commands {
    let viewModel: HostCommandsViewModelType

    var body: some Commands {
        CommandGroup(replacing: .saveItem) {
            SavePresetMenu(viewModel: viewModel)
        }
    }
}

private struct SavePresetMenu: View {
    @State var viewModel: HostCommandsViewModelType

    var body: some View {
        Button("Save Preset") {
            Task { await viewModel.accept(action: .save) }
        }
        .keyboardShortcut("s", modifiers: .command)
        .disabled(!viewModel.canSave)

        Button("Restore Preset") {
            Task { await viewModel.accept(action: .restore) }
        }
        .keyboardShortcut("r", modifiers: .command)
        .disabled(!viewModel.canRestore)
    }
}
