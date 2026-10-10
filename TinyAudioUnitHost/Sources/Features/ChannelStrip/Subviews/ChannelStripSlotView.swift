//
//  ChannelStripSlotView.swift
//  TinyAudioUnitHost
//
//  Created by Alex Shubin on 10.10.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioUnitsKit
import SwiftUI

struct ChannelStripSlotView: View {
    let state: ChannelStripSlotViewState
    let onAction: (ChannelStripSlotViewAction) -> Void

    @State private var isHovered = false

    var body: some View {
        Group {
            if let loaded = state.loaded {
                loadedSlot(loaded)
            } else {
                emptySlot
            }
        }
        .frame(height: 36)
        .onHover { isHovered = $0 }
        .animation(.snappy(duration: 0.15), value: isHovered)
    }

    // MARK: - Loaded

    private func loadedSlot(_ loaded: ChannelStripSlotViewState.Loaded) -> some View {
        HStack(spacing: .zero) {
            Button {
                onAction(.toggleBypass)
            } label: {
                Image(systemName: "power")
                    .font(.system(size: 10, weight: .bold))
                    .frame(width: 22)
                    .frame(maxHeight: .infinity)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .opacity(isHovered || loaded.isBypassed ? 1 : 0)

            Button {
                onAction(.select)
            } label: {
                VStack(spacing: 1) {
                    Text(loaded.name)
                        .font(.system(size: 11, weight: .semibold))
                    Text(loaded.manufacturer)
                        .font(.system(size: 9, weight: .medium))
                        .opacity(0.7)
                }
                .lineLimit(1)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Menu {
                loadedMenu
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .bold))
                    .frame(width: 22)
                    .frame(maxHeight: .infinity)
                    .contentShape(Rectangle())
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .opacity(isHovered ? 1 : 0)
        }
        .foregroundStyle(loaded.isBypassed ? Color.secondary : .white)
        .background { slotFill(loaded) }
        .overlay {
            if loaded.isSelected {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(.white.opacity(0.9), lineWidth: 1.5)
            }
        }
        .help("\(loaded.name) — \(loaded.manufacturer)")
        .contextMenu { loadedMenu }
    }

    @ViewBuilder
    private var loadedMenu: some View {
        Button("No Plug-in") { onAction(.remove) }
        catalogMenu
    }

    private func slotFill(_ loaded: ChannelStripSlotViewState.Loaded) -> some View {
        let shape = RoundedRectangle(cornerRadius: 7, style: .continuous)
        return shape
            .fill(Color(nsColor: .windowBackgroundColor))
            .overlay { shape.fill(loaded.isBypassed ? Color.gray.opacity(0.3) : loaded.kind.tint) }
    }

    // MARK: - Empty

    private var emptySlot: some View {
        Menu {
            catalogMenu
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(isHovered ? .primary : .tertiary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color(nsColor: .windowBackgroundColor))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .strokeBorder(
                            isHovered ? .secondary : .quaternary,
                            style: StrokeStyle(lineWidth: 1, dash: [4, 3])
                        )
                }
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .help("Add Plug-in")
    }

    // MARK: - Catalog

    @ViewBuilder
    private var catalogMenu: some View {
        ForEach(state.catalogs) { catalog in
            Section(catalog.title) {
                ForEach(catalog.pluginGroups) { group in
                    Menu(group.manufacturer) {
                        ForEach(group.components) { component in
                            Button(component.name) { onAction(.load(component)) }
                        }
                    }
                }
            }
        }
    }
}

enum ChannelStripSlotViewAction {
    case select
    case toggleBypass
    case load(AudioUnitComponent)
    case remove
}

struct ChannelStripSlotViewState: Equatable, Identifiable {
    struct Loaded: Equatable {
        let name: String
        let manufacturer: String
        let kind: AudioUnitComponent.Kind
        let isBypassed: Bool
        let isSelected: Bool
    }

    struct Catalog: Equatable, Identifiable {
        struct PluginGroup: Equatable, Identifiable {
            let manufacturer: String
            let components: [AudioUnitComponent]

            var id: String { manufacturer }
        }

        let title: String
        let pluginGroups: [PluginGroup]

        var id: String { title }
    }

    let id: Int
    let loaded: Loaded?
    let catalogs: [Catalog]
}

private extension AudioUnitComponent.Kind {
    var tint: Color {
        switch self {
        case .instrument: Color(red: 0.20, green: 0.56, blue: 0.30)
        case .effect: Color(red: 0.22, green: 0.47, blue: 0.90)
        }
    }
}
