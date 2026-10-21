//
//  PresetsView.swift
//  TinyAudioUnitHost
//
//  Created by Alex Shubin on 20.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import SwiftUI

struct PresetsView: View {
    @State var presenter: PresetsPresenter
    @Environment(\.dependencies) private var dependencies

    var body: some View {
        List(selection: selectionBinding) {
            Section {
                ForEach(presenter.presets, id: \.self) { preset in
                    Text(preset)
                        .tag(preset)
                        .contextMenu {
                            Button("Rename") {
                                presenter.rename(name: preset)
                            }
                            Button("Delete", role: .destructive) {
                                presenter.delete(name: preset)
                            }
                        }
                }
            } header: {
                HStack {
                    Text("Presets")
                        .font(.headline)
                    Spacer()
                    Button {
                        presenter.saveAs()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.primary, .secondary.opacity(0.35))
                            .font(.headline)
                            .padding(.trailing, 8)
                    }
                    .buttonStyle(.plain)
                    .disabled(presenter.isSaveAsButtonDisabled)
                    .help("Save current sound as a new preset")
                }
                .padding(.vertical, 8)
            }
        }
        .listStyle(.sidebar)
        .disabled(presenter.isInteractionDisabled)
        .sheet(item: $presenter.presentedNameDialogMode) { mode in
            PresetNameDialogView(
                presenter: dependencies.makePresetNameDialogPresenter(mode: mode)
            )
        }
    }

    private var selectionBinding: Binding<String?> {
        Binding(
            get: { presenter.activeName },
            set: { newSelection in
                if let newSelection {
                    Task { await presenter.select(name: newSelection) }
                }
            }
        )
    }
}
