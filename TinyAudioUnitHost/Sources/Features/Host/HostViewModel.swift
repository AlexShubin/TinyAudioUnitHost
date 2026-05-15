//
//  HostViewModel.swift
//  TinyAudioUnitHost
//
//  Created by Alex Shubin on 19.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioSettingsKit
import AudioUnitsKit
import EngineKit
import Foundation
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
    case failed(String)

    var isLoaded: Bool {
        if case .loaded = self { return true }
        return false
    }
}

@MainActor
protocol HostViewModelType: AnyObject, Observable {
    var groups: [ManufacturerGroup] { get }
    var selectedComponent: AudioUnitComponent? { get }
    var content: HostContent { get }
    var unmetRequirements: Set<SetupRequirement> { get }
    var isReady: Bool { get }
    func accept(action: HostViewModelAction) async
}

@MainActor @Observable
final class HostViewModel: HostViewModelType {
    private(set) var groups: [ManufacturerGroup] = []
    private(set) var selectedComponent: AudioUnitComponent?
    private(set) var content: HostContent = .loading
    private(set) var unmetRequirements: Set<SetupRequirement> = []

    var isReady: Bool { unmetRequirements.isEmpty }

    @ObservationIgnored private let library: AudioUnitComponentsLibraryType
    @ObservationIgnored private let engine: EngineType
    @ObservationIgnored private let presetProvider: PresetProviderType
    @ObservationIgnored private let setupChecker: SetupCheckerType
    @ObservationIgnored private var setupListener: Task<Void, Never>?

    init(
        library: AudioUnitComponentsLibraryType,
        engine: EngineType,
        presetProvider: PresetProviderType,
        setupChecker: SetupCheckerType
    ) {
        self.library = library
        self.engine = engine
        self.presetProvider = presetProvider
        self.setupChecker = setupChecker
        setupListener = Task { [weak self, setupChecker] in
            for await unmet in setupChecker.unmetStream {
                self?.unmetRequirements = unmet
            }
        }
    }

    deinit {
        setupListener?.cancel()
    }

    func accept(action: HostViewModelAction) async {
        switch action {
        case .task:
            groups = grouped(library.components)
            await setupChecker.refresh()
            guard case .loading = content else { return }
            guard let saved = await presetProvider.loadDefault() else {
                content = .empty
                return
            }
            await load(component: saved.component, state: saved.state)
        case .selected(let component):
            guard isReady else { return }
            selectedComponent = component
            content = .loading
            await load(component: component, state: nil)
        case .groupExpansionChanged(let manufacturer, let isExpanded):
            guard let index = groups.firstIndex(where: { $0.manufacturer == manufacturer }) else { return }
            groups[index].isExpanded = isExpanded
        case .saveCurrentPreset:
            guard case .loaded(let loaded) = content,
                  let state = loaded.audioUnit.fullState else { return }
            await presetProvider.saveDefault(Preset(component: loaded.component, state: state))
        case .restorePreset:
            guard let saved = await presetProvider.loadDefault() else {
                selectedComponent = nil
                content = .empty
                return
            }
            await load(component: saved.component, state: saved.state)
        }
    }

    private func load(component: AudioUnitComponent, state: Data?) async {
        do {
            let loaded = try await engine.load(component: component, state: state)
            selectedComponent = loaded.component
            content = .loaded(loaded)
        } catch let error as EngineLoadError {
            content = .failed(error.message)
        } catch {
            content = .failed("Couldn't load this audio unit.")
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

private extension EngineLoadError {
    var message: String {
        switch self {
        case .audioUnitInstantiationFailed: return "Couldn't load this audio unit."
        case .deviceUnavailable: return "Audio device is unavailable. Check Settings."
        }
    }
}
