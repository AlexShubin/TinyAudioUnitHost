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
protocol HostViewModelType: Observable {
    var groups: [ManufacturerGroup] { get }
    var selectedComponent: AudioUnitComponent? { get }
    var content: HostContent { get }
    var presetTitle: String { get }
    func accept(action: HostViewModelAction) async
}

@MainActor @Observable
final class HostViewModel: HostViewModelType {
    private static let presetName = "default"

    private(set) var groups: [ManufacturerGroup] = []
    private(set) var selectedComponent: AudioUnitComponent?
    private(set) var content: HostContent = .empty
    private(set) var isModified: Bool = false

    var presetTitle: String { "Preset: Default\(isModified ? "*" : "")" }

    @ObservationIgnored private let engine: EngineType
    @ObservationIgnored private let library: AudioUnitComponentsLibraryType
    @ObservationIgnored private let presetProvider: PresetProviderType

    init(
        engine: EngineType,
        library: AudioUnitComponentsLibraryType,
        presetProvider: PresetProviderType
    ) {
        self.engine = engine
        self.library = library
        self.presetProvider = presetProvider
    }

    func accept(action: HostViewModelAction) async {
        switch action {
        case .task:
            groups = grouped(library.components)
            guard let preset = await presetProvider.load(name: Self.presetName),
                  let loaded = await engine.load(component: preset.component, state: preset.state) else { return }
            selectedComponent = preset.component
            content = .loaded(loaded)
            installModificationListener(for: loaded)
        case .selected(let component):
            selectedComponent = component
            content = .loading
            isModified = true
            if let loaded = await engine.load(component: component, state: nil) {
                content = .loaded(loaded)
            }
        case .groupExpansionChanged(let manufacturer, let isExpanded):
            guard let index = groups.firstIndex(where: { $0.manufacturer == manufacturer }) else { return }
            groups[index].isExpanded = isExpanded
        case .saveCurrentPreset:
            guard case .loaded(let loaded) = content,
                  let state = loaded.audioUnit.fullState else { return }
            await presetProvider.save(Preset(component: loaded.component, state: state), name: Self.presetName)
            isModified = false
            installModificationListener(for: loaded)
        }
    }

    private func installModificationListener(for loaded: LoadedAudioUnit) {
        loaded.audioUnit.onChange { [weak self] in
            Task { @MainActor in
                self?.isModified = true
            }
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
