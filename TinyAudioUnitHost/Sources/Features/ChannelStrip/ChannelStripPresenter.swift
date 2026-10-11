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
        session.slots.first?.component?.kind == .instrument ? "Instrument" : "Input"
    }

    var sourceSlot: ChannelStripSlotViewState {
        slotState(at: 0)
    }

    var insertSlots: [ChannelStripSlotViewState] {
        (1..<session.slots.count + 1).map(slotState)
    }

    private let library: AudioUnitComponentsLibraryType
    private let session: SessionModelType

    init(library: AudioUnitComponentsLibraryType, session: SessionModelType) {
        self.library = library
        self.session = session
    }

    func handleSlot(_ action: ChannelStripSlotViewAction, at index: Int) async {
        switch action {
        case .select:
            session.select(index)
        case .load(let component):
            await session.load(component, at: index)
        case .remove:
            await session.unload(at: index)
        case .toggleBypass:
            guard case .loaded(_, let isBypassed) = slot(at: index) else { return }
            session.setBypassed(!isBypassed, at: index)
        }
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
        guard session.setup == .met else {
            return slot.component.map { .disabled(component: $0) } ?? .empty(isEnabled: false)
        }
        let isSelected = session.selectedIndex == index
        switch slot {
        case .empty, .failed(component: nil, _):
            return .empty(isEnabled: true)
        case .pending(let component):
            return .disabled(component: component)
        case .loading(let component):
            return .loading(component: component)
        case .loaded(let audioUnit, let isBypassed):
            return .loaded(
                component: audioUnit.component,
                bypass: audioUnit.component.bypass(isBypassed: isBypassed),
                isSelected: isSelected
            )
        case .failed(let component?, _):
            return .failed(component: component, isSelected: isSelected)
        }
    }

    private func slot(at index: Int) -> PluginSlotContent {
        session.slots.indices.contains(index) ? session.slots[index] : .empty
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
        case .pending(let component), .loading(let component): component
        case .loaded(let audioUnit, _): audioUnit.component
        case .failed(let component, _): component
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
