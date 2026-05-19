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
import PurchasesKit

enum HostViewModelAction {
    case task
    case selected(AudioUnitComponent)
    case groupExpansionChanged(manufacturer: String, isExpanded: Bool)
    case saveCurrentPreset
    case restorePreset
    case newPresetTapped
    case presetSelected(name: String)
    case presetRenameTapped(name: String)
    case presetDeleteTapped(name: String)
    case feedbackToastAction(FeedbackToastAction)
    case presetNameDialogAction(PresetNameDialogAction)
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
    var feedback: FeedbackToastViewState? { get }
    var isReady: Bool { get }
    var isPro: Bool { get }
    var presets: [Preset] { get }
    var activeName: String? { get }
    var presetNameDialog: PresetNameDialogState? { get }
    var openProWindowRequest: UUID? { get }
    func accept(action: HostViewModelAction) async
}

@MainActor @Observable
final class HostViewModel: HostViewModelType {
    private(set) var groups: [ManufacturerGroup] = []
    private(set) var selectedComponent: AudioUnitComponent?
    private(set) var content: HostContent = .loading
    private(set) var unmetRequirements: Set<SetupRequirement> = []
    private(set) var feedback: FeedbackToastViewState?
    private(set) var isPro: Bool = false
    private(set) var allPresets: [Preset] = []
    private(set) var activeName: String?
    private(set) var presetNameDialog: PresetNameDialogState?
    private(set) var openProWindowRequest: UUID?

    var isReady: Bool { unmetRequirements.isEmpty }

    var presets: [Preset] {
        isPro ? allPresets : Array(allPresets.prefix(2))
    }

    @ObservationIgnored private let library: AudioUnitComponentsLibraryType
    @ObservationIgnored private let engine: EngineType
    @ObservationIgnored private let presetProvider: PresetProviderType
    @ObservationIgnored private let presetNameValidator: PresetNameValidatorType
    @ObservationIgnored private let setupChecker: SetupCheckerType
    @ObservationIgnored private let purchasesService: PurchasesServiceType
    @ObservationIgnored private var setupListener: Task<Void, Never>?

    init(
        library: AudioUnitComponentsLibraryType,
        engine: EngineType,
        presetProvider: PresetProviderType,
        setupChecker: SetupCheckerType,
        presetNameValidator: PresetNameValidatorType,
        purchasesService: PurchasesServiceType
    ) {
        self.library = library
        self.engine = engine
        self.presetProvider = presetProvider
        self.setupChecker = setupChecker
        self.presetNameValidator = presetNameValidator
        self.purchasesService = purchasesService
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
            isPro = await purchasesService.isPro
            allPresets = presetProvider.presets
            let storedActive = presetProvider.activeName
            if let storedActive, let preset = presetProvider.load(name: storedActive) {
                activeName = storedActive
                await load(component: preset.component, state: preset.state)
            } else {
                if storedActive != nil {
                    presetProvider.setActive(nil)
                }
                activeName = nil
                content = .empty
            }
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
                  let activeName,
                  let state = loaded.audioUnit.fullState else { return }
            let preset = Preset(name: activeName, component: loaded.component, state: state)
            presetProvider.save(preset)
            allPresets = presetProvider.presets
            feedback = FeedbackToastViewState(id: UUID(), kind: .saved)
        case .feedbackToastAction(.timedOut):
            feedback = nil
        case .restorePreset:
            guard let activeName,
                  let saved = presetProvider.load(name: activeName) else { return }
            content = .loading
            await load(component: saved.component, state: saved.state)
            if case .loaded = content {
                feedback = FeedbackToastViewState(id: UUID(), kind: .restored)
            }
        case .presetSelected(let name):
            guard isReady else { return }
            presetProvider.setActive(name)
            activeName = name
            if let preset = presetProvider.load(name: name) {
                content = .loading
                await load(component: preset.component, state: preset.state)
            } else {
                selectedComponent = nil
                content = .empty
            }
        case .presetRenameTapped(let name):
            presetNameDialog = PresetNameDialogState(
                name: name,
                error: nil,
                mode: .rename(currentName: name)
            )
        case .presetDeleteTapped(let name):
            presetProvider.delete(name: name)
            allPresets = presetProvider.presets
            activeName = presetProvider.activeName
        case .newPresetTapped:
            isPro = await purchasesService.isPro
            allPresets = presetProvider.presets
            if !isPro && presets.count >= 2 {
                openProWindowRequest = UUID()
            } else {
                presetNameDialog = PresetNameDialogState(name: "", error: nil, mode: .create)
            }
        case .presetNameDialogAction(.nameChanged(let name)):
            guard let current = presetNameDialog else { return }
            let error = presetNameValidator.validate(name: name, for: current.mode.validationMode)
            presetNameDialog = PresetNameDialogState(name: name, error: error, mode: current.mode)
        case .presetNameDialogAction(.cancel):
            presetNameDialog = nil
        case .presetNameDialogAction(.commit):
            guard let dialog = presetNameDialog else { return }
            switch dialog.mode {
            case .create:
                guard case .loaded(let loaded) = content,
                      let state = loaded.audioUnit.fullState else { return }
                let preset = Preset(name: dialog.name, component: loaded.component, state: state)
                switch presetProvider.saveAs(preset) {
                case .success(let saved):
                    presetProvider.setActive(saved.name)
                    activeName = saved.name
                    allPresets = presetProvider.presets
                    presetNameDialog = nil
                    feedback = FeedbackToastViewState(id: UUID(), kind: .saved)
                case .failure(let error):
                    presetNameDialog = PresetNameDialogState(name: dialog.name, error: error, mode: dialog.mode)
                }
            case .rename(let currentName):
                switch presetProvider.rename(from: currentName, to: dialog.name) {
                case .success:
                    allPresets = presetProvider.presets
                    activeName = presetProvider.activeName
                    presetNameDialog = nil
                case .failure(let error):
                    presetNameDialog = PresetNameDialogState(name: dialog.name, error: error, mode: dialog.mode)
                }
            }
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

private extension PresetNameDialogState.Mode {
    var validationMode: ValidationMode {
        switch self {
        case .create: return .saveAs
        case .rename(let currentName): return .rename(currentName: currentName)
        }
    }
}
