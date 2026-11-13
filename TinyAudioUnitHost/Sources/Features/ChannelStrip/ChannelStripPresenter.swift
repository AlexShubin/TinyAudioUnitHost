//
//  ChannelStripPresenter.swift
//  TinyAudioUnitHost
//
//  Created by Alex Shubin on 10.10.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioSettingsKit
import AudioUnitsKit
import ChannelStripKit
import Observation
import PurchasesKit

@MainActor @Observable
final class ChannelStripPresenter {
    var sourceTitle: String {
        channelStrip.slots.first?.component?.kind == .instrument ? "Instrument" : "Input"
    }

    var sourceSlot: ChannelStripSlotViewState {
        slotState(at: 0)
    }

    var insertSlots: [ChannelStripSlotViewState] {
        (1..<channelStrip.slots.count + 1).map(slotState)
    }

    private(set) var isProWindowRequested = false

    private var canAddPlugin: Bool {
        purchases.state.isPro || channelStrip.slots.isEmpty
    }

    private let library: AudioUnitComponentsLibraryType
    private let channelStrip: ChannelStripModelType
    private let audioSettings: AudioSettingsModelType
    private let purchases: PurchasesModelType

    init(
        library: AudioUnitComponentsLibraryType,
        channelStrip: ChannelStripModelType,
        audioSettings: AudioSettingsModelType,
        purchases: PurchasesModelType
    ) {
        self.library = library
        self.channelStrip = channelStrip
        self.audioSettings = audioSettings
        self.purchases = purchases
    }

    func handleSlot(_ action: ChannelStripSlotViewAction, at index: Int) async {
        switch action {
        case .select:
            channelStrip.select(index: index)
        case .load(let component):
            await channelStrip.load(component: component, at: index)
        case .remove:
            await channelStrip.unload(at: index)
        case .toggleBypass:
            guard case .loaded(_, let isBypassed) = slot(at: index) else { return }
            channelStrip.setBypassed(!isBypassed, at: index)
        case .unlock:
            isProWindowRequested = true
        }
    }

    func proWindowOpened() {
        isProWindowRequested = false
    }

    private func slotState(at index: Int) -> ChannelStripSlotViewState {
        ChannelStripSlotViewState(
            id: index,
            content: content(at: index),
            catalogs: index == 0
                ? [catalog("Instruments", kind: .instrument), catalog("Effects", kind: .effect)]
                : [catalog("Effects", kind: .effect)]
        )
    }

    private func content(at index: Int) -> ChannelStripSlotViewState.Content {
        let slot = slot(at: index)
        guard audioSettings.setup == .met else {
            return slot.component.map { .disabled(component: $0) } ?? .empty(isEnabled: false)
        }
        let isSelected = channelStrip.selectedIndex == index
        switch slot {
        case .empty:
            return canAddPlugin ? .empty(isEnabled: true) : .locked
        case .loading(let component):
            return .loading(component: component)
        case .loaded(let audioUnit, let isBypassed):
            return .loaded(
                component: audioUnit.component,
                bypass: audioUnit.component.bypass(isBypassed: isBypassed),
                isSelected: isSelected
            )
        case .failed(let component, _, _, _):
            return .failed(component: component, isSelected: isSelected)
        }
    }

    private func slot(at index: Int) -> PluginSlotContent {
        channelStrip.slots.indices.contains(index) ? channelStrip.slots[index] : .empty
    }

    private func catalog(_ title: String, kind: AudioUnitComponent.Kind) -> ChannelStripSlotViewState.Catalog {
        let pluginGroups = Dictionary(grouping: library.components.filter { $0.kind == kind }, by: \.manufacturer)
            .map { ChannelStripSlotViewState.Catalog.PluginGroup(manufacturer: $0.key, components: $0.value) }
            .sorted { $0.manufacturer.localizedCaseInsensitiveCompare($1.manufacturer) == .orderedAscending }
        return ChannelStripSlotViewState.Catalog(title: title, pluginGroups: pluginGroups)
    }
}

private extension PluginSlotContent {
    var component: AudioUnitComponent? {
        switch self {
        case .empty: nil
        case .loading(let component): component
        case .loaded(let audioUnit, _): audioUnit.component
        case .failed(let component, _, _, _): component
        }
    }
}

private extension AudioUnitComponent {
    func bypass(isBypassed: Bool) -> ChannelStripSlotViewState.Bypass {
        switch kind {
        case .instrument: .unavailable
        case .effect: isBypassed ? .bypassed : .active
        }
    }
}
