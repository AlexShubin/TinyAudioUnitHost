//
//  PresetsSidebarView.swift
//  TinyAudioUnitHost
//
//  Created by Alex Shubin on 20.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import PresetKit
import SwiftUI

struct PresetsSidebarView: View {
    @State var viewModel: PresetsSidebarViewModelType
    @Environment(\.dependencies) private var dependencies

    var body: some View {
        Group {
            if viewModel.presets.isEmpty {
                ContentUnavailableView(
                    "No Presets Yet",
                    systemImage: "rectangle.stack",
                    description: Text("Use + in the toolbar to save the current sound as a preset.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(selection: selectionBinding) {
                    Section("Presets") {
                        ForEach(viewModel.presets, id: \.name) { preset in
                            Text(preset.name)
                                .tag(preset.name)
                                .contextMenu {
                                    Button("Rename") {
                                        Task { await viewModel.accept(action: .renameTapped(name: preset.name)) }
                                    }
                                    Button("Delete", role: .destructive) {
                                        Task { await viewModel.accept(action: .deleteTapped(name: preset.name)) }
                                    }
                                }
                        }
                    }
                }
                .listStyle(.sidebar)
                .disabled(viewModel.isInteractionDisabled)
            }
        }
        .sheet(isPresented: renameDialogPresented) {
            if let target = viewModel.renameTarget {
                PresetNameDialogView(
                    viewModel: dependencies.makePresetNameDialogViewModel(
                        mode: .rename(currentName: target),
                        initialName: target
                    )
                )
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

    private var renameDialogPresented: Binding<Bool> {
        Binding(
            get: { viewModel.renameTarget != nil },
            set: { isPresented in
                if !isPresented {
                    Task { await viewModel.accept(action: .dismissRenameDialog) }
                }
            }
        )
    }
}
