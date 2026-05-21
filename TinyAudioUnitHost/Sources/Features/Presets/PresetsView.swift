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
            } header: {
                HStack {
                    Text("Presets")
                    Spacer()
                    Button {
                        Task { await viewModel.accept(action: .saveAsTapped) }
                    } label: {
                        Image(systemName: "plus.circle")
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.isSaveAsButtonDisabled)
                    .help("Save current sound as a new preset")
                }
            }
        }
        .listStyle(.sidebar)
        .disabled(viewModel.isInteractionDisabled)
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
        .sheet(isPresented: saveAsDialogPresented) {
            PresetNameDialogView(
                viewModel: dependencies.makePresetNameDialogViewModel(mode: .saveAs, initialName: "")
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

    private var saveAsDialogPresented: Binding<Bool> {
        Binding(
            get: { viewModel.isSaveAsDialogPresented },
            set: { isPresented in
                if !isPresented {
                    Task { await viewModel.accept(action: .dismissSaveAsDialog) }
                }
            }
        )
    }
}
