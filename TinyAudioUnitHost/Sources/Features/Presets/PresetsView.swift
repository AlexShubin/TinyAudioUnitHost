//
//  PresetsView.swift
//  TinyAudioUnitHost
//
//  Created by Alex Shubin on 20.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import PresetKit
import SwiftUI

struct PresetsView: View {
    @State var viewModel: PresetsViewModelType
    @Environment(\.dependencies) private var dependencies
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        List(selection: selectionBinding) {
            Section {
                ForEach(viewModel.presets, id: \.self) { preset in
                    Text(preset)
                        .tag(preset)
                        .contextMenu {
                            Button("Rename") {
                                Task { await viewModel.accept(action: .renameTapped(name: preset)) }
                            }
                            Button("Delete", role: .destructive) {
                                Task { await viewModel.accept(action: .deleteTapped(name: preset)) }
                            }
                        }
                }
            } header: {
                HStack {
                    Text("Presets")
                        .font(.headline)
                    Spacer()
                    Button {
                        Task { await viewModel.accept(action: .saveAsTapped) }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.primary, .secondary.opacity(0.35))
                            .font(.headline)
                            .padding(.trailing, 8)
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.isSaveAsButtonDisabled)
                    .help("Save current sound as a new preset")
                }
                .padding(.vertical, 8)
            }
        }
        .listStyle(.sidebar)
        .disabled(viewModel.isInteractionDisabled)
        .sheet(item: presentedPresetNameDialogBinding) { mode in
            PresetNameDialogView(
                viewModel: dependencies.makePresetNameDialogViewModel(mode: mode)
            )
        }
        .onChange(of: viewModel.openProWindowRequest) { _, newValue in
            if newValue != nil {
                openWindow(id: "purchases")
            }
        }
    }

    private var selectionBinding: Binding<String?> {
        Binding(
            get: { viewModel.activeName },
            set: { newSelection in
                if let newSelection {
                    Task { await viewModel.accept(action: .selected(name: newSelection)) }
                }
            }
        )
    }

    private var presentedPresetNameDialogBinding: Binding<PresetNameDialogMode?> {
        Binding(
            get: { viewModel.presentedPresetNameDialog },
            set: { newMode in
                if newMode == nil {
                    Task { await viewModel.accept(action: .dismissDialog) }
                }
            }
        )
    }
}
