//
//  SessionModel.swift
//  TinyAudioUnitHost
//
//  Created by Alex Shubin on 20.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioSettingsKit
import AudioUnitsKit
import EngineKit
import Foundation
import Observation
import PresetKit

@MainActor
protocol SessionModelType: AnyObject, Observable, Sendable {
    var content: HostContent { get }
    var activeName: String? { get }
    var presets: [String] { get }
    var presetEvent: PresetEvent? { get }

    func acknowledgePresetEvent()
    func refreshSetup() async
    func loadComponent(_ component: AudioUnitComponent) async
    func selectPreset(name: String) async
    func saveCurrentPreset()
    func restoreActivePreset() async
    func saveAsNewPreset(name: String)
    func renamePreset(from: String, to: String)
    func deletePreset(name: String)
}

struct PresetEvent: Sendable, Equatable {
    enum Kind: Sendable, Equatable {
        case saved
        case restored
    }

    let id: UUID
    let kind: Kind
}

enum HostContent: Sendable, Equatable {
    case idle
    case unmet(Set<SetupRequirement>)
    case empty
    case loading
    case loaded(LoadedAudioUnit)
    case failed(String)

    var isLoaded: Bool {
        if case .loaded = self { return true }
        return false
    }

    /// True for states the user can act on from the UI. False before setup
    /// is checked (.idle), while loading, and when blocked (.unmet).
    var isOperable: Bool {
        switch self {
        case .empty, .loaded, .failed: return true
        case .idle, .loading, .unmet: return false
        }
    }
}

@MainActor @Observable
final class SessionModel: SessionModelType {
    private(set) var content: HostContent = .idle
    private(set) var activeName: String?
    private(set) var presets: [String] = []
    private(set) var presetEvent: PresetEvent?

    @ObservationIgnored private let engine: EngineType
    @ObservationIgnored private let presetProvider: PresetProviderType
    @ObservationIgnored private let setupChecker: SetupCheckerType

    init(
        engine: EngineType,
        presetProvider: PresetProviderType,
        setupChecker: SetupCheckerType
    ) {
        self.engine = engine
        self.presetProvider = presetProvider
        self.setupChecker = setupChecker
        presets = presetProvider.presets
    }

    func refreshSetup() async {
        await applyUnmet(setupChecker.check())
    }

    func acknowledgePresetEvent() {
        presetEvent = nil
    }

    func loadComponent(_ component: AudioUnitComponent) async {
        await load(component: component, state: nil)
    }

    func selectPreset(name: String) async {
        presetProvider.setActive(name)
        activeName = name
        await loadActivePreset()
    }

    func saveCurrentPreset() {
        guard case .loaded(let audioUnit) = content,
              let activeName,
              let state = audioUnit.fullState else { return }
        let preset = Preset(name: activeName, component: audioUnit.component, state: state)
        presetProvider.save(preset)
        presets = presetProvider.presets
        presetEvent = PresetEvent(id: UUID(), kind: .saved)
    }

    func restoreActivePreset() async {
        guard let activeName,
              let saved = presetProvider.load(name: activeName) else { return }
        await load(component: saved.component, state: saved.state)
        if case .loaded = content {
            presetEvent = PresetEvent(id: UUID(), kind: .restored)
        }
    }

    func saveAsNewPreset(name: String) {
        guard case .loaded(let audioUnit) = content,
              let state = audioUnit.fullState else { return }
        let preset = Preset(name: name, component: audioUnit.component, state: state)
        presetProvider.save(preset)
        presetProvider.setActive(preset.name)
        activeName = preset.name
        presets = presetProvider.presets
        presetEvent = PresetEvent(id: UUID(), kind: .saved)
    }

    func renamePreset(from: String, to: String) {
        presetProvider.rename(from: from, to: to)
        presets = presetProvider.presets
        activeName = presetProvider.activeName
    }

    func deletePreset(name: String) {
        presetProvider.delete(name: name)
        presets = presetProvider.presets
        activeName = presetProvider.activeName
    }

    private func applyUnmet(_ next: Set<SetupRequirement>) async {
        if !next.isEmpty {
            content = .unmet(next)
            return
        }
        switch content {
        case .idle, .unmet:
            activeName = presetProvider.activeName
            await loadActivePreset()
        case .loading, .empty, .loaded, .failed:
            break
        }
    }

    private func loadActivePreset() async {
        guard let active = activeName else {
            content = .empty
            return
        }
        if let preset = presetProvider.load(name: active) {
            await load(component: preset.component, state: preset.state)
        } else {
            content = .failed("Couldn't load this preset.")
        }
    }

    private func load(component: AudioUnitComponent, state: Data?) async {
        content = .loading
        let result: HostContent
        do {
            result = .loaded(try await engine.load(component: component, state: state))
        } catch {
            result = .failed(error.message)
        }
        if case .loading = content {
            content = result
        }
    }
}

private extension EngineLoadError {
    var message: String {
        switch self {
        case .audioUnitInstantiationFailed: return "Couldn't load this audio unit."
        case .deviceUnavailable: return "Audio device is unavailable. Check Settings."
        }
    }
}
