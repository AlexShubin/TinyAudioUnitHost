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
        slots[sourceIndex]?.component.kind == .instrument ? "Instrument" : "Input"
    }

    var sourceSlot: ChannelStripSlotViewState {
        slotState(at: sourceIndex)
    }

    var insertSlots: [ChannelStripSlotViewState] {
        (sourceIndex + 1 ..< slots.count).map(slotState)
    }

    private let sourceIndex = 0
    private var selectedIndex: Int?
    private var slots: [PrototypeSlot?] = Array(repeating: nil, count: 6)

    private let library: AudioUnitComponentsLibraryType

    init(library: AudioUnitComponentsLibraryType) {
        self.library = library
    }

    func handleSlot(_ action: ChannelStripSlotViewAction, at index: Int) {
        switch action {
        case .select:
            selectedIndex = index
        case .toggleBypass:
            slots[index]?.isBypassed.toggle()
        case .load(let component):
            slots[index] = PrototypeSlot(component: component)
            selectedIndex = index
        case .remove:
            slots[index] = nil
            if selectedIndex == index {
                selectedIndex = nil
            }
        }
    }

    private func slotState(at index: Int) -> ChannelStripSlotViewState {
        ChannelStripSlotViewState(
            id: index,
            loaded: slots[index].map { slot in
                ChannelStripSlotViewState.Loaded(
                    name: slot.component.name,
                    manufacturer: slot.component.manufacturer,
                    kind: slot.component.kind,
                    isBypassed: slot.isBypassed,
                    isSelected: selectedIndex == index
                )
            },
            catalogs: index == sourceIndex
                ? [catalog("Instruments", kind: .instrument), catalog("Effects", kind: .effect)]
                : [catalog("Effects", kind: .effect)]
        )
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
