//
//  HostViewModel.swift
//  TinyAudioUnitHost
//
//  Created by Alex Shubin on 19.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import Observation

enum HostViewModelAction {
    case task
    case selected(AudioUnitComponent)
    case groupExpansionChanged(manufacturer: String, isExpanded: Bool)
}

@MainActor
protocol HostViewModelType: Observable {
    var state: HostViewState { get }
    func accept(action: HostViewModelAction) async
}

@MainActor @Observable
final class HostViewModel: HostViewModelType {
    private(set) var state = HostViewState.initial

    @ObservationIgnored private let engine: AudioUnitHostEngineType
    @ObservationIgnored private let library: AudioUnitComponentsLibraryType

    init(engine: AudioUnitHostEngineType, library: AudioUnitComponentsLibraryType) {
        self.engine = engine
        self.library = library
    }

    func accept(action: HostViewModelAction) async {
        switch action {
        case .task:
            state.groups = grouped(library.components)
        case .selected(let component):
            state.selectedComponent = component
            state.audioUnit = nil
            state.audioUnit = await engine.load(component: component)
        case .groupExpansionChanged(let manufacturer, let isExpanded):
            guard let index = state.groups.firstIndex(where: { $0.manufacturer == manufacturer }) else { return }
            state.groups[index].isExpanded = isExpanded
        }
    }

    private func grouped(_ components: [AudioUnitComponent]) -> [ManufacturerGroup] {
        Dictionary(grouping: components, by: \.manufacturer)
            .map { ManufacturerGroup(manufacturer: $0.key, components: $0.value, isExpanded: false) }
            .sorted { $0.manufacturer.localizedCaseInsensitiveCompare($1.manufacturer) == .orderedAscending }
    }
}
