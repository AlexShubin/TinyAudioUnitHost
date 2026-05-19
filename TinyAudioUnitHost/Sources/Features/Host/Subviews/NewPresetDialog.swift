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
        VStack(spacing: 20) {
            Image(systemName: "rectangle.stack.fill")
                .font(.system(size: 36))
                .foregroundStyle(.white)
                .frame(width: 80, height: 80)
                .background(Color.accentColor.gradient, in: Circle())
                .padding(.top, 24)

            VStack(alignment: .leading, spacing: 4) {
                TextField("Preset Name", text: nameBinding)
                    .textFieldStyle(.roundedBorder)
                    .font(.title3)
                    .onSubmit { onAction(.commit) }
                if let message = state.error?.displayMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            .padding(.horizontal, 24)

            HStack {
                Button("Cancel", role: .cancel) { onAction(.cancel) }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Create") { onAction(.commit) }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canCommit)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .frame(width: 440)
    }

    private var nameBinding: Binding<String> {
        Binding(
            get: { state.name },
            set: { onAction(.nameChanged($0)) }
        )
    }

    private var canCommit: Bool {
        state.error == nil
            && !state.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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

private extension PresetNameError {
    var displayMessage: String? {
        switch self {
        case .empty: return nil
        case .invalidCharacter: return "Name can't contain /, :, or start with a dot."
        case .duplicate: return "A preset with that name already exists."
        }
    }
}
