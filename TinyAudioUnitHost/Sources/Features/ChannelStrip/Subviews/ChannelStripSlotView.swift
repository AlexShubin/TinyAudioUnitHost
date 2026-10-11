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
            case .disabled(let component):
                inactiveSlot(component, fill: component.kind.tint.opacity(0.35), isLoading: false)
                    .foregroundStyle(.secondary)
            case .loading(let component):
                inactiveSlot(component, fill: component.kind.tint, isLoading: true)
                    .foregroundStyle(.white)
            case .loaded(let component, let bypass, let isSelected):
                loadedSlot(component, bypass: bypass, isSelected: isSelected)
            case .failed(let component, let isSelected):
                failedSlot(component, isSelected: isSelected)
            }
        }
        .frame(height: 36)
        .onHover { isHovered = $0 }
        .animation(.snappy(duration: 0.15), value: isHovered)
    }

    // MARK: - Loaded

    private func loadedSlot(
        _ component: AudioUnitComponent,
        bypass: ChannelStripSlotViewState.Bypass,
        isSelected: Bool
    ) -> some View {
        let isBypassed = bypass == .bypassed
        return interactiveSlot(component, isSelected: isSelected) {
            if bypass == .unavailable {
                Color.clear
                    .frame(width: 22)
            } else {
                bypassButton(isBypassed: isBypassed)
            }
        }
        .foregroundStyle(isBypassed ? Color.secondary : .white)
        .background { slotFill(isBypassed ? Color.gray.opacity(0.3) : component.kind.tint) }
    }

    private func failedSlot(_ component: AudioUnitComponent, isSelected: Bool) -> some View {
        interactiveSlot(component, isSelected: isSelected) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 9, weight: .bold))
                .frame(width: 22)
        }
        .foregroundStyle(.secondary)
        .background { slotFill(component.kind.tint.opacity(0.35)) }
    }

    private func interactiveSlot(
        _ component: AudioUnitComponent,
        isSelected: Bool,
        @ViewBuilder leading: () -> some View
    ) -> some View {
        HStack(spacing: .zero) {
            leading()

            Button {
                onAction(.select)
            } label: {
                pluginLabel(component)
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
        .overlay {
            if isSelected {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(.white.opacity(0.9), lineWidth: 1.5)
            }
        }
        .help("\(component.name) — \(component.manufacturer)")
        .contextMenu { loadedMenu }
    }

    private func bypassButton(isBypassed: Bool) -> some View {
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
    }

    @ViewBuilder
    private var loadedMenu: some View {
        Button("No Plug-in") { onAction(.remove) }
        catalogMenu
    }

    // MARK: - Loading / Disabled

    private func inactiveSlot(_ component: AudioUnitComponent, fill: Color, isLoading: Bool) -> some View {
        pluginLabel(component)
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

    private func pluginLabel(_ component: AudioUnitComponent) -> some View {
        VStack(spacing: 1) {
            Text(component.name)
                .font(.system(size: 11, weight: .semibold))
            Text(component.manufacturer)
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
                .overlay {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .strokeBorder(
                            isHighlighted ? .secondary : .quaternary,
                            style: StrokeStyle(lineWidth: 1, dash: [4, 3])
                        )
                }
                .contentShape(Rectangle())
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .disabled(!isEnabled)
        .background {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Color(nsColor: .windowBackgroundColor))
        }
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
        case disabled(component: AudioUnitComponent)
        case loading(component: AudioUnitComponent)
        case loaded(component: AudioUnitComponent, bypass: Bypass, isSelected: Bool)
        case failed(component: AudioUnitComponent, isSelected: Bool)
    }

    enum Bypass {
        case unavailable
        case active
        case bypassed
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
