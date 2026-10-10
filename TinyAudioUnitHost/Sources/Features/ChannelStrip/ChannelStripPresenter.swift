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
        session.content.audioUnit?.component.kind == .instrument ? "Instrument" : "Input"
    }

    var sourceSlot: ChannelStripSlotViewState {
        ChannelStripSlotViewState(
            id: sourceIndex,
            loaded: session.content.audioUnit.map { loaded($0.component, isBypassed: false, at: sourceIndex) },
            catalogs: [catalog("Instruments", kind: .instrument), catalog("Effects", kind: .effect)]
        )
    }

    var insertSlots: [ChannelStripSlotViewState] {
        insertIndices.map { index in
            ChannelStripSlotViewState(
                id: index,
                loaded: inserts[index].map { loaded($0.component, isBypassed: $0.isBypassed, at: index) },
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

    private func loaded(_ component: AudioUnitComponent, isBypassed: Bool, at index: Int) -> ChannelStripSlotViewState.Loaded {
        ChannelStripSlotViewState.Loaded(
            name: component.name,
            manufacturer: component.manufacturer,
            kind: component.kind,
            isBypassed: isBypassed,
            isSelected: selectedIndex == index
        )
    }

    private func catalog(_ title: String, kind: AudioUnitComponent.Kind) -> ChannelStripSlotViewState.Catalog {
        let pluginGroups = Dictionary(grouping: library.components.filter { $0.kind == kind }, by: \.manufacturer)
            .map { ChannelStripSlotViewState.Catalog.PluginGroup(manufacturer: $0.key, components: $0.value) }
            .sorted { $0.manufacturer.localizedCaseInsensitiveCompare($1.manufacturer) == .orderedAscending }
        return ChannelStripSlotViewState.Catalog(title: title, pluginGroups: pluginGroups)
    }
}

private extension HostContent {
    var audioUnit: LoadedAudioUnit? {
        guard case .loaded(let audioUnit) = self else { return nil }
        return audioUnit
    }
}

private struct PrototypeSlot {
    let component: AudioUnitComponent
    var isBypassed = false
}
