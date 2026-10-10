//
//  ChannelStripSlotView.swift
//  TinyAudioUnitHost
//
//  Created by Alex Shubin on 10.10.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import SwiftUI

struct ChannelStripSlotView: View {
    let state: ChannelStripSlotViewState
    let onAction: (ChannelStripSlotAction) -> Void

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
        .animation(.snappy(duration: 0.2), value: state.loaded)
    }

    // MARK: - Loaded

    private func loadedSlot(_ loaded: ChannelStripSlotViewState.Loaded) -> some View {
        HStack(spacing: .zero) {
            Button {
                onAction(.toggleBypass)
            } label: {
                Image(systemName: "power")
                    .font(.system(size: 10, weight: .bold))
                    .frame(width: 22, height: 36)
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
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Menu {
                loadedMenu
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .bold))
                    .frame(width: 22, height: 36)
                    .contentShape(Rectangle())
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .opacity(isHovered ? 1 : 0)
        }
        .foregroundStyle(loaded.isBypassed ? AnyShapeStyle(.secondary) : AnyShapeStyle(.white))
        .background { slotFill(loaded) }
        .overlay { slotBorder(loaded) }
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

    private func slotBorder(_ loaded: ChannelStripSlotViewState.Loaded) -> some View {
        RoundedRectangle(cornerRadius: 7, style: .continuous)
            .strokeBorder(
                loaded.isSelected
                    ? AnyShapeStyle(.white.opacity(0.9))
                    : AnyShapeStyle(LinearGradient(colors: [.white.opacity(0.35), .clear], startPoint: .top, endPoint: .bottom)),
                lineWidth: loaded.isSelected ? 1.5 : 0.5
            )
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
                            isHovered ? AnyShapeStyle(.secondary) : AnyShapeStyle(.quaternary),
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
        ForEach(state.catalog) { section in
            Section(section.title) {
                ForEach(section.manufacturers) { manufacturer in
                    Menu(manufacturer.name) {
                        ForEach(manufacturer.plugins) { plugin in
                            Button(plugin.name) { onAction(.load(plugin)) }
                        }
                    }
                }
            }
        }
    }
}

enum ChannelStripSlotAction {
    case select
    case toggleBypass
    case load(ChannelStripPlugin)
    case remove
}

struct ChannelStripSlotViewState: Equatable, Identifiable {
    struct Loaded: Equatable {
        let name: String
        let manufacturer: String
        let kind: ChannelStripPluginKind
        let isBypassed: Bool
        let isSelected: Bool
    }

    let id: Int
    let loaded: Loaded?
    let catalog: [ChannelStripCatalogSection]
}

struct ChannelStripCatalogSection: Equatable, Identifiable {
    let title: String
    let manufacturers: [ChannelStripCatalogManufacturer]

    var id: String { title }
}

struct ChannelStripCatalogManufacturer: Equatable, Identifiable {
    let name: String
    let plugins: [ChannelStripPlugin]

    var id: String { name }
}

struct ChannelStripPlugin: Equatable, Identifiable {
    let name: String
    let manufacturer: String
    let kind: ChannelStripPluginKind

    var id: String { "\(manufacturer).\(name)" }
}

enum ChannelStripPluginKind {
    case instrument
    case effect
}

private extension ChannelStripPluginKind {
    var tint: Color {
        switch self {
        case .instrument: Color(red: 0.20, green: 0.56, blue: 0.30)
        case .effect: Color(red: 0.22, green: 0.47, blue: 0.90)
        }
    }
}
