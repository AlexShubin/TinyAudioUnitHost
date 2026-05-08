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
import PresetKit

enum HostViewModelAction {
    case task
    case selected(AudioUnitComponent)
    case groupExpansionChanged(manufacturer: String, isExpanded: Bool)
    case saveCurrentPreset
}

enum HostContent: Sendable, Equatable {
    case empty
    case loading
    case loaded(LoadedAudioUnit)
}

@MainActor
protocol HostViewModelType: AnyObject, Observable {
    var groups: [ManufacturerGroup] { get }
    var selectedComponent: AudioUnitComponent? { get }
    var content: HostContent { get }
    var presetTitle: String { get }
    var isModified: Bool { get }
    func accept(action: HostViewModelAction) async
}

@MainActor @Observable
final class HostViewModel: HostViewModelType {
    private(set) var groups: [ManufacturerGroup] = []
    private(set) var selectedComponent: AudioUnitComponent?
    private(set) var content: HostContent = .empty
    private(set) var isModified: Bool = false

    var presetTitle: String { "Preset: Default\(isModified ? "*" : "")" }

    @ObservationIgnored private let engine: EngineType
    @ObservationIgnored private let library: AudioUnitComponentsLibraryType
    @ObservationIgnored private let presetManager: PresetManagerType
    @ObservationIgnored private var modificationListener: Task<Void, Never>?

    init(
        engine: EngineType,
        library: AudioUnitComponentsLibraryType,
        presetManager: PresetManagerType
    ) {
        self.engine = engine
        self.library = library
        self.presetManager = presetManager
        modificationListener = Task { [weak self, presetManager] in
            for await flag in presetManager.isModifiedStream {
                self?.isModified = flag
            }
        }
    }

    deinit {
        modificationListener?.cancel()
    }

    func accept(action: HostViewModelAction) async {
        switch action {
        case .task:
            groups = grouped(library.components)
            guard case .empty = content else { return }
            guard let active = await presetManager.load(),
                  let loaded = await engine.load(component: active.preset.component, state: active.preset.state)
            else { return }
            selectedComponent = active.preset.component
            content = .loaded(loaded)
            await presetManager.setCurrent(loaded, isModified: active.isModified)
        case .selected(let component):
            selectedComponent = component
            content = .loading
            if let loaded = await engine.load(component: component, state: nil) {
                content = .loaded(loaded)
                await presetManager.setCurrent(loaded, isModified: true)
            }
        case .groupExpansionChanged(let manufacturer, let isExpanded):
            guard let index = groups.firstIndex(where: { $0.manufacturer == manufacturer }) else { return }
            groups[index].isExpanded = isExpanded
        case .saveCurrentPreset:
            guard case .loaded = content else { return }
            await presetManager.save()
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
