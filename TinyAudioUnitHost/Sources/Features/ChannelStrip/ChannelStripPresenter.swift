//
//  ChannelStripPresenter.swift
//  TinyAudioUnitHost
//
//  Created by Alex Shubin on 10.10.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioUnitsKit
import Observation

@MainActor @Observable
final class ChannelStripPresenter {
    var sourceTitle: String {
        session.sourceSlot.component?.kind == .instrument ? "Instrument" : "Input"
    }

    var sourceSlot: ChannelStripSlotViewState {
        ChannelStripSlotViewState(
            id: sourceIndex,
            content: sourceContent,
            catalogs: [catalog("Instruments", kind: .instrument), catalog("Effects", kind: .effect)]
        )
    }

    var insertSlots: [ChannelStripSlotViewState] {
        insertIndices.map { index in
            ChannelStripSlotViewState(
                id: index,
                content: inserts[index].map { insert in
                    .loaded(plugin: insert.component.plugin, isBypassed: insert.isBypassed, isSelected: selectedIndex == index)
                } ?? .empty(isEnabled: true),
                catalogs: [catalog("Effects", kind: .effect)]
            )
        }
    }

    private let sourceIndex = 0
    private let insertIndices = 1...5
    private var selectedIndex: Int? = 0
    private var inserts: [Int: PrototypeSlot] = [:]

    private let library: AudioUnitComponentsLibraryType
    private let session: SessionModelType

    init(library: AudioUnitComponentsLibraryType, session: SessionModelType) {
        self.library = library
        self.session = session
    }

    func handleSource(_ action: ChannelStripSlotViewAction) async {
        switch action {
        case .select:
            selectedIndex = sourceIndex
        case .load(let component):
            selectedIndex = sourceIndex
            await session.loadComponent(component)
        case .toggleBypass, .remove:
            break
        }
    }

    func handleInsert(_ action: ChannelStripSlotViewAction, at index: Int) {
        switch action {
        case .select:
            selectedIndex = index
        case .toggleBypass:
            inserts[index]?.isBypassed.toggle()
        case .load(let component):
            inserts[index] = PrototypeSlot(component: component)
            selectedIndex = index
        case .remove:
            inserts[index] = nil
            if selectedIndex == index {
                selectedIndex = nil
            }
        }
    }

    private var sourceContent: ChannelStripSlotViewState.Content {
        switch session.sourceSlot {
        case .empty(let isEnabled):
            .empty(isEnabled: isEnabled)
        case .disabled(let component):
            .disabled(plugin: component.plugin)
        case .loading(let component):
            .loading(plugin: component.plugin)
        case .loaded(let audioUnit):
            .loaded(plugin: audioUnit.component.plugin, isBypassed: false, isSelected: selectedIndex == sourceIndex)
        }
    }

    private func catalog(_ title: String, kind: AudioUnitComponent.Kind) -> ChannelStripSlotViewState.Catalog {
        let pluginGroups = Dictionary(grouping: library.components.filter { $0.kind == kind }, by: \.manufacturer)
            .map { ChannelStripSlotViewState.Catalog.PluginGroup(manufacturer: $0.key, components: $0.value) }
            .sorted { $0.manufacturer.localizedCaseInsensitiveCompare($1.manufacturer) == .orderedAscending }
        return ChannelStripSlotViewState.Catalog(title: title, pluginGroups: pluginGroups)
    }
}

private struct PrototypeSlot {
    let component: AudioUnitComponent
    var isBypassed = false
}

private extension PluginSlotContent {
    var component: AudioUnitComponent? {
        switch self {
        case .empty: nil
        case .disabled(let component), .loading(let component): component
        case .loaded(let audioUnit): audioUnit.component
        }
    }
}

private extension AudioUnitComponent {
    var plugin: ChannelStripSlotViewState.Plugin {
        ChannelStripSlotViewState.Plugin(name: name, manufacturer: manufacturer, kind: kind)
    }
}
