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

enum QuitDecision: Sendable {
    case save
    case discard
    case cancel
}

enum HostViewModelAction {
    case task
    case selected(AudioUnitComponent)
    case groupExpansionChanged(manufacturer: String, isExpanded: Bool)
    case saveCurrentPreset
    case quit(QuitDecision)
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
    var isQuitAlertShown: Bool { get }
    func accept(action: HostViewModelAction) async
}

@MainActor @Observable
final class HostViewModel: HostViewModelType {
    private(set) var groups: [ManufacturerGroup] = []
    private(set) var selectedComponent: AudioUnitComponent?
    private(set) var content: HostContent = .empty
    private(set) var isModified: Bool = false
    private(set) var isQuitAlertShown: Bool = false

    var presetTitle: String { "Preset: Default\(isModified ? "*" : "")" }

    @ObservationIgnored private let engine: EngineType
    @ObservationIgnored private let library: AudioUnitComponentsLibraryType
    @ObservationIgnored private let presetManager: PresetManagerType
    @ObservationIgnored private let quitCoordinator: QuitCoordinatorType
    @ObservationIgnored private var modificationTask: Task<Void, Never>?
    @ObservationIgnored private var quitRequestTask: Task<Void, Never>?

    init(
        engine: EngineType,
        library: AudioUnitComponentsLibraryType,
        presetManager: PresetManagerType,
        quitCoordinator: QuitCoordinatorType
    ) {
        self.engine = engine
        self.library = library
        self.presetManager = presetManager
        self.quitCoordinator = quitCoordinator
        installQuitRequestListener()
    }

    func accept(action: HostViewModelAction) async {
        switch action {
        case .task:
            groups = grouped(library.components)
            guard case .empty = content else { return }
            guard let preset = await presetManager.load(),
                  let loaded = await engine.load(component: preset.component, state: preset.state)
            else { return }
            selectedComponent = preset.component
            content = .loaded(loaded)
            isModified = false
            installModificationListener(for: loaded)
        case .selected(let component):
            selectedComponent = component
            content = .loading
            isModified = true
            if let loaded = await engine.load(component: component, state: nil) {
                content = .loaded(loaded)
                installModificationListener(for: loaded)
            }
        case .groupExpansionChanged(let manufacturer, let isExpanded):
            guard let index = groups.firstIndex(where: { $0.manufacturer == manufacturer }) else { return }
            groups[index].isExpanded = isExpanded
        case .saveCurrentPreset:
            guard case .loaded(let loaded) = content else { return }
            await presetManager.save(loaded)
            isModified = false
        case .quit(let decision):
            switch decision {
            case .save:
                await accept(action: .saveCurrentPreset)
                await quitCoordinator.resolve(proceed: true)
            case .discard:
                await quitCoordinator.resolve(proceed: true)
            case .cancel:
                await quitCoordinator.resolve(proceed: false)
            }
            isQuitAlertShown = false
        }
    }

    private func installQuitRequestListener() {
        quitRequestTask?.cancel()
        quitRequestTask = Task { [weak self, coordinator = quitCoordinator] in
            for await _ in coordinator.requests {
                guard let self else { return }
                if isModified {
                    isQuitAlertShown = true
                } else {
                    await coordinator.resolve(proceed: true)
                }
            }
        }
    }

    private func installModificationListener(for loaded: LoadedAudioUnit) {
        modificationTask?.cancel()
        modificationTask = Task { [weak self, audioUnit = loaded.audioUnit] in
            for await _ in audioUnit.modifications {
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
