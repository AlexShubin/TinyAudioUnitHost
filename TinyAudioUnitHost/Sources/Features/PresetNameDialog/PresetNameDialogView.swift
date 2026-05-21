//
//  PresetNameDialogView.swift
//  TinyAudioUnitHost
//
//  Created by Alex Shubin on 19.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import PresetKit
import SwiftUI

struct PresetNameDialogView: View {
    @State var viewModel: PresetNameDialogViewModelType
    @Environment(\.dismiss) private var dismiss

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
                    .onSubmit { Task { await viewModel.accept(action: .commit) } }
                if let message = viewModel.error?.displayMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            .padding(.horizontal, 24)

            HStack {
                Button("Cancel", role: .cancel) {
                    Task { await viewModel.accept(action: .cancel) }
                }
                .keyboardShortcut(.cancelAction)
                Spacer()
                Button(commitLabel) {
                    Task { await viewModel.accept(action: .commit) }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!canCommit)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .frame(width: 440)
        .onChange(of: viewModel.isDismissed) { _, isDismissed in
            if isDismissed { dismiss() }
        }
    }

    private var nameBinding: Binding<String> {
        Binding(
            get: { viewModel.name },
            set: { newValue in
                Task { await viewModel.accept(action: .nameChanged(newValue)) }
            }
        )
    }

    private var commitLabel: String {
        switch viewModel.mode {
        case .create: return "Create"
        case .rename: return "Rename"
        }
    }

    private var canCommit: Bool {
        viewModel.error == nil
            && !viewModel.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
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
