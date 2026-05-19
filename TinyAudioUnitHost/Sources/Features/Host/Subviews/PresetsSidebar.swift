//
//  PresetsSidebar.swift
//  TinyAudioUnitHost
//
//  Created by Alex Shubin on 19.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import PresetKit
import SwiftUI

struct PresetsSidebar: View {
    let state: PresetsSidebarViewState
    let onAction: (PresetsSidebarAction) -> Void

    @State private var renameTarget: String?
    @State private var renameNewName: String = ""

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            list
        }
        .alert(
            "Rename Preset",
            isPresented: renameAlertPresented,
            presenting: renameTarget
        ) { _ in
            TextField("Name", text: $renameNewName)
            Button("Cancel", role: .cancel) { renameTarget = nil }
            Button("Rename") {
                if let target = renameTarget {
                    onAction(.rename(from: target, to: renameNewName))
                }
                renameTarget = nil
            }
        }
    }

    private var header: some View {
        HStack {
            Text("Presets")
                .font(.headline)
                .foregroundStyle(.secondary)
            Spacer()
            Button {
                onAction(.addTapped)
            } label: {
                Image(systemName: "plus")
            }
            .buttonStyle(.borderless)
            .disabled(!state.canAdd)
            .help("New Preset")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var list: some View {
        if state.presets.isEmpty {
            ContentUnavailableView(
                "No Presets Yet",
                systemImage: "rectangle.stack",
                description: Text("Tap + to save the current sound as a preset.")
            )
        } else {
            List(selection: selectionBinding) {
                ForEach(state.presets, id: \.name) { preset in
                    Text(preset.name)
                        .tag(preset.name)
                        .contextMenu {
                            Button("Rename") {
                                renameTarget = preset.name
                                renameNewName = preset.name
                            }
                            Button("Delete", role: .destructive) {
                                onAction(.delete(name: preset.name))
                            }
                        }
                }
            }
            .listStyle(.sidebar)
        }
    }

    private var selectionBinding: Binding<String?> {
        Binding(
            get: { state.activeName },
            set: { newSelection in
                if let newSelection {
                    onAction(.selected(name: newSelection))
                }
            }
        )
    }

    private var renameAlertPresented: Binding<Bool> {
        Binding(
            get: { renameTarget != nil },
            set: { if !$0 { renameTarget = nil } }
        )
    }
}

enum PresetsSidebarAction: Sendable, Equatable {
    case selected(name: String)
    case addTapped
    case rename(from: String, to: String)
    case delete(name: String)
}

struct PresetsSidebarViewState: Sendable, Equatable {
    let presets: [Preset]
    let activeName: String?
    let canAdd: Bool
}
