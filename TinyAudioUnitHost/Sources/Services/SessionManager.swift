//
//  SessionManager.swift
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
import PurchasesKit

@MainActor
protocol SessionManagerType: AnyObject, Observable, Sendable {
    var content: HostContent { get }
    var activeName: String? { get }
    var presets: [Preset] { get }    // already free-tier capped

    func makeEventStream() -> AsyncStream<SessionEvent>

    func start() async
    func requestSaveAs() async
    func loadComponent(_ component: AudioUnitComponent) async
    func selectPreset(name: String) async
    func saveCurrentPreset()
    func restoreActivePreset() async
    func saveAsNewPreset(name: String) -> Result<Preset, PresetNameError>
    func renamePreset(from: String, to: String) -> Result<Void, PresetNameError>
    func deletePreset(name: String)
}

enum HostContent: Sendable, Equatable {
    case unmet(Set<SetupRequirement>)
    case empty
    case loading
    case loaded(LoadedAudioUnit)
    case failed(String)

    var isLoaded: Bool {
        if case .loaded = self { return true }
        return false
    }

    /// True for states the user can act on from the UI. False for transient
    /// (.loading) and blocked (.unmet) states where input should be disabled.
    var isOperable: Bool {
        switch self {
        case .empty, .loaded, .failed: return true
        case .loading, .unmet: return false
        }
    }
}

enum SessionEvent: Sendable, Equatable {
    case saved
    case restored
    case requestSaveAsDialog
    case requestProUpgrade
}

@MainActor @Observable
final class SessionManager: SessionManagerType {
    private(set) var content: HostContent = .loading
    private(set) var activeName: String?
    private(set) var allPresets: [Preset] = []
    private var isPro: Bool = false
    private var unmet: Set<SetupRequirement>?

    @ObservationIgnored private var continuations: [UUID: AsyncStream<SessionEvent>.Continuation] = [:]

    var presets: [Preset] {
        isPro ? allPresets : Array(allPresets.prefix(2))
    }

    @ObservationIgnored private let engine: EngineType
    @ObservationIgnored private let presetProvider: PresetProviderType
    @ObservationIgnored private let purchasesService: PurchasesServiceType
    @ObservationIgnored private let setupChecker: SetupCheckerType
    @ObservationIgnored private var setupListener: Task<Void, Never>?

    nonisolated init(
        engine: EngineType,
        presetProvider: PresetProviderType,
        purchasesService: PurchasesServiceType,
        setupChecker: SetupCheckerType
    ) {
        self.engine = engine
        self.presetProvider = presetProvider
        self.purchasesService = purchasesService
        self.setupChecker = setupChecker
    }

    deinit {
        setupListener?.cancel()
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
        if setupListener == nil {
            setupListener = Task { @MainActor [weak self, setupChecker] in
                for await next in setupChecker.unmetStream {
                    guard let self else { break }
                    await self.applyUnmet(next)
                }
            }
        }
        await setupChecker.refresh()
    }

    func requestSaveAs() async {
        isPro = await purchasesService.isPro
        if isPro || allPresets.count < 2 {
            emit(.requestSaveAsDialog)
        } else {
            emit(.requestProUpgrade)
        }
    }

    func loadComponent(_ component: AudioUnitComponent) async {
        guard isReady else { return }
        content = .loading
        await load(component: component, state: nil)
    }

    func selectPreset(name: String) async {
        guard isReady else { return }
        presetProvider.setActive(name)
        activeName = name
        if let preset = presetProvider.load(name: name) {
            content = .loading
            await load(component: preset.component, state: preset.state)
        } else {
            content = .empty
        }
    }

    func saveCurrentPreset() {
        guard case .loaded(let loaded) = content,
              let activeName,
              let state = loaded.audioUnit.fullState else { return }
        let preset = Preset(name: activeName, component: loaded.component, state: state)
        presetProvider.save(preset)
        allPresets = presetProvider.presets
        emit(.saved)
    }

    func restoreActivePreset() async {
        guard let activeName,
              let saved = presetProvider.load(name: activeName) else { return }
        content = .loading
        await load(component: saved.component, state: saved.state)
        if case .loaded = content {
            emit(.restored)
        }
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

    private var isReady: Bool { unmet?.isEmpty == true }

    private func applyUnmet(_ next: Set<SetupRequirement>) async {
        let previous = unmet
        unmet = next
        if !next.isEmpty {
            content = .unmet(next)
            return
        }
        // next is empty — first time we see "good setup", or transition from unmet.
        if previous != next {
            await loadActivePreset()
        }
    }

    private func loadActivePreset() async {
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

    private func load(component: AudioUnitComponent, state: Data?) async {
        do {
            let loaded = try await engine.load(component: component, state: state)
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
