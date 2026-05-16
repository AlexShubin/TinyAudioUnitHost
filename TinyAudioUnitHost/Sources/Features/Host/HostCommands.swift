//
//  HostCommands.swift
//  TinyAudioUnitHost
//
//  Created by Alex Shubin on 15.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import SwiftUI

struct SavePresetActions {
    let save: @MainActor () -> Void?
    let restore: @MainActor () -> Void?
}

extension FocusedValues {
    @Entry var savePresetActions: SavePresetActions?
}

struct HostCommands: Commands {
    var body: some Commands {
        CommandGroup(replacing: .saveItem) {
            SavePresetMenu()
        }
    }
}

private struct SavePresetMenu: View {
    @FocusedValue(\.savePresetActions) private var savePresetActions

    var body: some View {
        Button("Save Preset") { savePresetActions?.save() }
            .keyboardShortcut("s", modifiers: .command)
            .disabled(savePresetActions == nil)
        Button("Restore Preset") { savePresetActions?.restore() }
            .keyboardShortcut("r", modifiers: .command)
            .disabled(savePresetActions == nil)
    }
}
