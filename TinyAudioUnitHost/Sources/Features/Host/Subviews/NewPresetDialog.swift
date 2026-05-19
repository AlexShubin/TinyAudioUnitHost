//
//  NewPresetDialog.swift
//  TinyAudioUnitHost
//
//  Created by Alex Shubin on 19.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import PresetKit
import SwiftUI

struct NewPresetDialog: View {
    let state: NewPresetDialogState
    let onAction: (NewPresetDialogAction) -> Void

    var body: some View {
        // Body to be implemented in the dialog step (icon + text field +
        // Cancel/Create). The state + action shape is settled.
        EmptyView()
    }
}

enum NewPresetDialogAction: Sendable, Equatable {
    case nameChanged(String)
    case cancel
    case commit
}

struct NewPresetDialogState: Sendable, Equatable {
    var name: String
    var error: PresetNameError?
}
