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
            switch state.content {
            case .empty(let isEnabled):
                emptySlot(isEnabled: isEnabled)
            case .disabled(let plugin):
                inactiveSlot(plugin, fill: plugin.kind.tint.opacity(0.35), isLoading: false)
                    .foregroundStyle(.secondary)
            case .loading(let plugin):
                inactiveSlot(plugin, fill: plugin.kind.tint, isLoading: true)
                    .foregroundStyle(.white)
            case .loaded(let plugin, let isBypassed, let isSelected):
                loadedSlot(plugin, isBypassed: isBypassed, isSelected: isSelected)
            }
        }
        .frame(height: 36)
        .onHover { isHovered = $0 }
        .animation(.snappy(duration: 0.15), value: isHovered)
    }

    // MARK: - Loaded

    private func loadedSlot(_ plugin: ChannelStripSlotViewState.Plugin, isBypassed: Bool, isSelected: Bool) -> some View {
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
            .opacity(isHovered || isBypassed ? 1 : 0)

            Button {
                onAction(.select)
            } label: {
                pluginLabel(plugin)
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
        .foregroundStyle(isBypassed ? Color.secondary : .white)
        .background { slotFill(isBypassed ? Color.gray.opacity(0.3) : plugin.kind.tint) }
        .overlay {
            if isSelected {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(.white.opacity(0.9), lineWidth: 1.5)
            }
        }
        .help("\(plugin.name) — \(plugin.manufacturer)")
        .contextMenu { loadedMenu }
    }

    @ViewBuilder
    private var loadedMenu: some View {
        Button("No Plug-in") { onAction(.remove) }
        catalogMenu
    }

    // MARK: - Loading / Disabled

    private func inactiveSlot(_ plugin: ChannelStripSlotViewState.Plugin, fill: Color, isLoading: Bool) -> some View {
        pluginLabel(plugin)
            .padding(.horizontal, 22)
            .overlay(alignment: .leading) {
                if isLoading {
                    ProgressView()
                        .controlSize(.mini)
                        .environment(\.colorScheme, .dark)
                        .frame(width: 22)
                }
            }
            .background { slotFill(fill) }
    }

    // MARK: - Shared

    private func pluginLabel(_ plugin: ChannelStripSlotViewState.Plugin) -> some View {
        VStack(spacing: 1) {
            Text(plugin.name)
                .font(.system(size: 11, weight: .semibold))
            Text(plugin.manufacturer)
                .font(.system(size: 9, weight: .medium))
                .opacity(0.7)
        }
        .lineLimit(1)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func slotFill(_ color: Color) -> some View {
        let shape = RoundedRectangle(cornerRadius: 7, style: .continuous)
        return shape
            .fill(Color(nsColor: .windowBackgroundColor))
            .overlay { shape.fill(color) }
    }

    // MARK: - Empty

    private func emptySlot(isEnabled: Bool) -> some View {
        let isHighlighted = isHovered && isEnabled
        return Menu {
            catalogMenu
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(isHighlighted ? .primary : .tertiary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color(nsColor: .windowBackgroundColor))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .strokeBorder(
                            isHighlighted ? .secondary : .quaternary,
                            style: StrokeStyle(lineWidth: 1, dash: [4, 3])
                        )
                }
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .disabled(!isEnabled)
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
    enum Content: Equatable {
        case empty(isEnabled: Bool)
        case disabled(plugin: Plugin)
        case loading(plugin: Plugin)
        case loaded(plugin: Plugin, isBypassed: Bool, isSelected: Bool)
    }

    struct Plugin: Equatable {
        let name: String
        let manufacturer: String
        let kind: AudioUnitComponent.Kind
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
    let content: Content
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
