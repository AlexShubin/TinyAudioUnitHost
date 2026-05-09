//
//  HostViewModel.swift
//  TinyAudioUnitHost
//
//  Created by Alex Shubin on 19.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioUnitsKit
import Observation
import PresetKit

enum HostViewModelAction {
    case task
    case selected(AudioUnitComponent)
    case groupExpansionChanged(manufacturer: String, isExpanded: Bool)
    case saveCurrentPreset
    case restorePreset
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
    var unmetRequirements: Set<SetupRequirement> { get }
    var isReady: Bool { get }
    func accept(action: HostViewModelAction) async
}

@MainActor @Observable
final class HostViewModel: HostViewModelType {
    private(set) var groups: [ManufacturerGroup] = []
    private(set) var selectedComponent: AudioUnitComponent?
    private(set) var content: HostContent = .empty
    private(set) var isModified: Bool = false
    private(set) var unmetRequirements: Set<SetupRequirement> = []

    var presetTitle: String { "Preset: Default\(isModified ? "*" : "")" }
    var isReady: Bool { unmetRequirements.isEmpty }

    @ObservationIgnored private let library: AudioUnitComponentsLibraryType
    @ObservationIgnored private let sessionManager: SessionManagerType
    @ObservationIgnored private let setupChecker: SetupCheckerType
    @ObservationIgnored private var modificationListener: Task<Void, Never>?
    @ObservationIgnored private var setupListener: Task<Void, Never>?

    init(
        library: AudioUnitComponentsLibraryType,
        sessionManager: SessionManagerType,
        setupChecker: SetupCheckerType
    ) {
        self.library = library
        self.sessionManager = sessionManager
        self.setupChecker = setupChecker
        modificationListener = Task { [weak self, sessionManager] in
            for await flag in sessionManager.isModifiedStream {
                self?.isModified = flag
            }
        }
        setupListener = Task { [weak self, setupChecker] in
            for await unmet in setupChecker.unmetStream {
                self?.unmetRequirements = unmet
            }
        }
    }

    deinit {
        modificationListener?.cancel()
        setupListener?.cancel()
    }

    func accept(action: HostViewModelAction) async {
        switch action {
        case .task:
            groups = grouped(library.components)
            guard case .empty = content else { return }
            guard let loaded = await sessionManager.activate(.stored) else { return }
            selectedComponent = loaded.component
            content = .loaded(loaded)
        case .selected(let component):
            guard isReady else { return }
            selectedComponent = component
            content = .loading
            if let loaded = await sessionManager.activate(.picked(component)) {
                content = .loaded(loaded)
            }
        case .groupExpansionChanged(let manufacturer, let isExpanded):
            guard let index = groups.firstIndex(where: { $0.manufacturer == manufacturer }) else { return }
            groups[index].isExpanded = isExpanded
        case .saveCurrentPreset:
            guard case .loaded = content else { return }
            await sessionManager.save()
        case .restorePreset:
            if let loaded = await sessionManager.activate(.savedDefault) {
                selectedComponent = loaded.component
                content = .loaded(loaded)
            } else {
                selectedComponent = nil
                content = .empty
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
