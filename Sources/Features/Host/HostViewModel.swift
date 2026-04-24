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
    var groups: [ManufacturerGroup] { get }
    var selectedComponent: AudioUnitComponent? { get }
    var audioUnit: LoadedAudioUnit? { get }
    func accept(action: HostViewModelAction) async
}

@MainActor @Observable
final class HostViewModel: HostViewModelType {
    private(set) var groups: [ManufacturerGroup] = []
    private(set) var selectedComponent: AudioUnitComponent?
    private(set) var audioUnit: LoadedAudioUnit?

    @ObservationIgnored private let engine: AudioUnitEngineManagerType
    @ObservationIgnored private let library: AudioUnitComponentsLibraryType

    init(engine: AudioUnitEngineManagerType, library: AudioUnitComponentsLibraryType) {
        self.engine = engine
        self.library = library
    }

    func accept(action: HostViewModelAction) async {
        switch action {
        case .task:
            groups = grouped(library.components)
        case .selected(let component):
            selectedComponent = component
            audioUnit = nil
            audioUnit = await engine.load(component: component)
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
