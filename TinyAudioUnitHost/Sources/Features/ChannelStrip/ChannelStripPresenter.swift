//
//  ChannelStripPresenter.swift
//  TinyAudioUnitHost
//
//  Created by Alex Shubin on 10.10.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import Observation

@MainActor @Observable
final class ChannelStripPresenter {
    var sourceTitle: String {
        slots[sourceIndex]?.plugin.kind == .instrument ? "Instrument" : "Input"
    }

    var sourceSlot: ChannelStripSlotViewState {
        slotState(at: sourceIndex)
    }

    var insertSlots: [ChannelStripSlotViewState] {
        (sourceIndex + 1 ..< slots.count).map(slotState)
    }

    private let sourceIndex = 0
    private var selectedIndex: Int? = 0
    private var slots: [PrototypeSlot?] = [
        PrototypeSlot(plugin: ChannelStripPlugin(name: "AUSampler", manufacturer: "Apple", kind: .instrument)),
        PrototypeSlot(plugin: ChannelStripPlugin(name: "AUDistortion", manufacturer: "Apple", kind: .effect)),
        PrototypeSlot(plugin: ChannelStripPlugin(name: "AUNBandEQ", manufacturer: "Apple", kind: .effect), isBypassed: true),
        PrototypeSlot(plugin: ChannelStripPlugin(name: "ValhallaDelay", manufacturer: "Valhalla DSP", kind: .effect)),
        nil,
        nil,
    ]

    private let catalog: [ChannelStripPlugin] = [
        ChannelStripPlugin(name: "AUSampler", manufacturer: "Apple", kind: .instrument),
        ChannelStripPlugin(name: "AUMIDISynth", manufacturer: "Apple", kind: .instrument),
        ChannelStripPlugin(name: "Pigments", manufacturer: "Arturia", kind: .instrument),
        ChannelStripPlugin(name: "Mini V4", manufacturer: "Arturia", kind: .instrument),
        ChannelStripPlugin(name: "AUDelay", manufacturer: "Apple", kind: .effect),
        ChannelStripPlugin(name: "AUDistortion", manufacturer: "Apple", kind: .effect),
        ChannelStripPlugin(name: "AUNBandEQ", manufacturer: "Apple", kind: .effect),
        ChannelStripPlugin(name: "AUPeakLimiter", manufacturer: "Apple", kind: .effect),
        ChannelStripPlugin(name: "AUReverb2", manufacturer: "Apple", kind: .effect),
        ChannelStripPlugin(name: "Pro-Q 4", manufacturer: "FabFilter", kind: .effect),
        ChannelStripPlugin(name: "ValhallaDelay", manufacturer: "Valhalla DSP", kind: .effect),
        ChannelStripPlugin(name: "ValhallaRoom", manufacturer: "Valhalla DSP", kind: .effect),
    ]

    func handleSlot(_ action: ChannelStripSlotAction, at index: Int) {
        switch action {
        case .select:
            selectedIndex = index
        case .toggleBypass:
            slots[index]?.isBypassed.toggle()
        case .load(let plugin):
            slots[index] = PrototypeSlot(plugin: plugin)
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
                    name: slot.plugin.name,
                    manufacturer: slot.plugin.manufacturer,
                    kind: slot.plugin.kind,
                    isBypassed: slot.isBypassed,
                    isSelected: selectedIndex == index
                )
            },
            catalog: index == sourceIndex
                ? [catalogSection("Instruments", kind: .instrument), catalogSection("Effects", kind: .effect)]
                : [catalogSection("Effects", kind: .effect)]
        )
    }

    private func catalogSection(_ title: String, kind: ChannelStripPluginKind) -> ChannelStripCatalogSection {
        let manufacturers = Dictionary(grouping: catalog.filter { $0.kind == kind }, by: \.manufacturer)
            .map { ChannelStripCatalogManufacturer(name: $0.key, plugins: $0.value) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        return ChannelStripCatalogSection(title: title, manufacturers: manufacturers)
    }
}

private struct PrototypeSlot {
    let plugin: ChannelStripPlugin
    var isBypassed = false
}
