//
//  SessionManager.swift
//  TinyAudioUnitHost
//
//  Created by Alex Shubin on 20.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioUnitsKit
import EngineKit
import Foundation
import Observation
import PresetKit
import PurchasesKit

@MainActor
protocol SessionManagerType: AnyObject, Observable, Sendable {
    var content: HostContent { get }
    var activeName: String? { get }
    var selectedComponent: AudioUnitComponent? { get }
    var presets: [Preset] { get }    // already free-tier capped

    func makeEventStream() -> AsyncStream<SessionEvent>

    func start() async
    func requestNewPreset() async
    func loadComponent(_ component: AudioUnitComponent) async
    func selectPreset(name: String) async
    func saveCurrentPreset() -> Bool
    func restoreActivePreset() async -> Bool
    func saveAsNewPreset(name: String) -> Result<Preset, PresetNameError>
    func renamePreset(from: String, to: String) -> Result<Void, PresetNameError>
    func deletePreset(name: String)
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

enum SessionEvent: Sendable, Equatable {
    case saved
    case restored
    case requestNewPresetDialog
    case requestProUpgrade
}

@MainActor @Observable
final class SessionManager: SessionManagerType {
    private(set) var content: HostContent = .loading
    private(set) var activeName: String?
    private(set) var selectedComponent: AudioUnitComponent?
    private(set) var allPresets: [Preset] = []
    private var isPro: Bool = false

    @ObservationIgnored private var continuations: [UUID: AsyncStream<SessionEvent>.Continuation] = [:]

    var presets: [Preset] {
        isPro ? allPresets : Array(allPresets.prefix(2))
    }

    @ObservationIgnored private let engine: EngineType
    @ObservationIgnored private let presetProvider: PresetProviderType
    @ObservationIgnored private let purchasesService: PurchasesServiceType

    nonisolated init(
        engine: EngineType,
        presetProvider: PresetProviderType,
        purchasesService: PurchasesServiceType
    ) {
        self.engine = engine
        self.presetProvider = presetProvider
        self.purchasesService = purchasesService
    }

    func makeEventStream() -> AsyncStream<SessionEvent> {
        AsyncStream { continuation in
            let id = UUID()
            self.continuations[id] = continuation
            continuation.onTermination = { _ in
                Task { @MainActor in
                    self.continuations.removeValue(forKey: id)
                }
            }
        }
    }

    private func emit(_ event: SessionEvent) {
        for continuation in continuations.values {
            continuation.yield(event)
        }
    }

    func start() async {
        guard case .loading = content else { return }
        isPro = await purchasesService.isPro
        allPresets = presetProvider.presets
        let storedActive = presetProvider.activeName
        if let storedActive, let preset = presetProvider.load(name: storedActive) {
            activeName = storedActive
            await load(component: preset.component, state: preset.state)
        } else {
            if storedActive != nil { presetProvider.setActive(nil) }
            activeName = nil
            content = .empty
        }
    }

    func requestNewPreset() async {
        isPro = await purchasesService.isPro
        if isPro || allPresets.count < 2 {
            emit(.requestNewPresetDialog)
        } else {
            emit(.requestProUpgrade)
        }
    }

    func loadComponent(_ component: AudioUnitComponent) async {
        selectedComponent = component
        content = .loading
        await load(component: component, state: nil)
    }

    func selectPreset(name: String) async {
        presetProvider.setActive(name)
        activeName = name
        if let preset = presetProvider.load(name: name) {
            content = .loading
            await load(component: preset.component, state: preset.state)
        } else {
            selectedComponent = nil
            content = .empty
        }
    }

    func saveCurrentPreset() -> Bool {
        guard case .loaded(let loaded) = content,
              let activeName,
              let state = loaded.audioUnit.fullState else { return false }
        let preset = Preset(name: activeName, component: loaded.component, state: state)
        presetProvider.save(preset)
        allPresets = presetProvider.presets
        emit(.saved)
        return true
    }

    func restoreActivePreset() async -> Bool {
        guard let activeName,
              let saved = presetProvider.load(name: activeName) else { return false }
        content = .loading
        await load(component: saved.component, state: saved.state)
        if case .loaded = content {
            emit(.restored)
            return true
        }
        return false
    }

    func saveAsNewPreset(name: String) -> Result<Preset, PresetNameError> {
        guard case .loaded(let loaded) = content,
              let state = loaded.audioUnit.fullState else { return .failure(.empty) }
        let preset = Preset(name: name, component: loaded.component, state: state)
        switch presetProvider.saveAs(preset) {
        case .success(let saved):
            presetProvider.setActive(saved.name)
            activeName = saved.name
            allPresets = presetProvider.presets
            emit(.saved)
            return .success(saved)
        case .failure(let error):
            return .failure(error)
        }
    }

    func renamePreset(from: String, to: String) -> Result<Void, PresetNameError> {
        switch presetProvider.rename(from: from, to: to) {
        case .success:
            allPresets = presetProvider.presets
            activeName = presetProvider.activeName
            return .success(())
        case .failure(let error):
            return .failure(error)
        }
    }

    func deletePreset(name: String) {
        presetProvider.delete(name: name)
        allPresets = presetProvider.presets
        activeName = presetProvider.activeName
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
}

private extension EngineLoadError {
    var message: String {
        switch self {
        case .audioUnitInstantiationFailed: return "Couldn't load this audio unit."
        case .deviceUnavailable: return "Audio device is unavailable. Check Settings."
        }
    }
}
