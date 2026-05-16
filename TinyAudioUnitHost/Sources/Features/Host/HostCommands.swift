//
//  HostCommands.swift
//  TinyAudioUnitHost
//
//  Created by Alex Shubin on 15.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import SwiftUI

struct SaveCurrentPresetAction {
    let perform: @MainActor () -> Void
}

struct RestorePresetAction {
    let perform: @MainActor () -> Void
}

extension FocusedValues {
    @Entry var saveCurrentPresetAction: SaveCurrentPresetAction?
    @Entry var restorePresetAction: RestorePresetAction?
}

struct HostCommands: Commands {
    var body: some Commands {
        CommandGroup(replacing: .saveItem) {
            SavePresetMenu()
        }
    }
}

private struct SavePresetMenu: View {
    @FocusedValue(\.saveCurrentPresetAction) private var saveAction
    @FocusedValue(\.restorePresetAction) private var restoreAction

    var body: some View {
        Button("Save Preset") { saveAction?.perform() }
            .keyboardShortcut("s", modifiers: .command)
            .disabled(saveAction == nil)
        Button("Restore Preset") { restoreAction?.perform() }
            .keyboardShortcut("r", modifiers: .command)
            .disabled(restoreAction == nil)
    }
}
