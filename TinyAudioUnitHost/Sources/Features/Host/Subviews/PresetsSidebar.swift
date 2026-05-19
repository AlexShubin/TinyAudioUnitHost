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
        list
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

    @ViewBuilder
    private var list: some View {
        if state.presets.isEmpty {
            ContentUnavailableView(
                "No Presets Yet",
                systemImage: "rectangle.stack",
                description: Text("Use + in the toolbar to save the current sound as a preset.")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List(selection: selectionBinding) {
                Section("Presets") {
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
            }
            .listStyle(.sidebar)
            .disabled(state.isInteractionDisabled)
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
    case rename(from: String, to: String)
    case delete(name: String)
}

struct PresetsSidebarViewState: Sendable, Equatable {
    let presets: [Preset]
    let activeName: String?
    let isInteractionDisabled: Bool
}
