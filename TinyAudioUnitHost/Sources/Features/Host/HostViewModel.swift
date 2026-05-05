//
//  HostViewModel.swift
//  TinyAudioUnitHost
//
//  Created by Alex Shubin on 19.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioUnitsKit
import EngineKit
import Observation

enum HostViewModelAction {
    case task
    case selected(AudioUnitComponent)
    case groupExpansionChanged(manufacturer: String, isExpanded: Bool)
}

enum HostContent: Sendable, Equatable {
    case empty
    case loading
    case loaded(LoadedAudioUnit)
}

@MainActor
protocol HostViewModelType: Observable {
    var groups: [ManufacturerGroup] { get }
    var selectedComponent: AudioUnitComponent? { get }
    var content: HostContent { get }
    func accept(action: HostViewModelAction) async
}

@MainActor @Observable
final class HostViewModel: HostViewModelType {
    private(set) var groups: [ManufacturerGroup] = []
    private(set) var selectedComponent: AudioUnitComponent?
    private(set) var content: HostContent = .empty

    @ObservationIgnored private let engine: EngineType
    @ObservationIgnored private let library: AudioUnitComponentsLibraryType

    init(
        engine: EngineType,
        library: AudioUnitComponentsLibraryType
    ) {
        self.engine = engine
        self.library = library
    }

    func accept(action: HostViewModelAction) async {
        switch action {
        case .task:
            groups = grouped(library.components)
        case .selected(let component):
            selectedComponent = component
            content = .loading
            if let loaded = await engine.load(component: component) {
                content = .loaded(loaded)
            }
        case .groupExpansionChanged(let manufacturer, let isExpanded):
            guard let index = groups.firstIndex(where: { $0.manufacturer == manufacturer }) else { return }
            groups[index].isExpanded = isExpanded
        }
    }

    private func grouped(_ components: [AudioUnitComponent]) -> [ManufacturerGroup] {
        Dictionary(grouping: components, by: \.manufacturer)
            .map { ManufacturerGroup(manufacturer: $0.key, components: $0.value, isExpanded: false) }
            .sorted { $0.manufacturer.localizedCaseInsensitiveCompare($1.manufacturer) == .orderedAscending }
    }
}

struct ManufacturerGroup: Identifiable, Hashable {
    let manufacturer: String
    let components: [AudioUnitComponent]
    var isExpanded: Bool

    var id: String { manufacturer }
}
