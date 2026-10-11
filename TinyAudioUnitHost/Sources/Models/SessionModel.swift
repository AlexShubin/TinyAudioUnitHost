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
    var sourceSlot: PluginSlotContent { get }
    var inserts: [PluginSlotContent] { get }
    var activeName: String? { get }
    var presets: [String] { get }
    var presetEvent: PresetEvent? { get }

    func acknowledgePresetEvent()
    func refreshSetup() async
    func loadComponent(_ component: AudioUnitComponent) async
    func unloadComponent() async
    func setSourceBypassed(_ isBypassed: Bool)
    func loadInsert(_ component: AudioUnitComponent, at index: Int) async
    func unloadInsert(at index: Int) async
    func setInsertBypassed(_ isBypassed: Bool, at index: Int)
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

enum PluginSlotContent: Sendable, Equatable {
    case empty(isEnabled: Bool)
    case disabled(component: AudioUnitComponent)
    case loading(component: AudioUnitComponent)
    case loaded(audioUnit: LoadedAudioUnit, isBypassed: Bool)
}

@MainActor @Observable
final class SessionModel: SessionModelType {
    private(set) var content: HostContent = .idle
    private(set) var sourceSlot: PluginSlotContent
    private(set) var inserts: [PluginSlotContent] = Array(repeating: .empty(isEnabled: false), count: 5)
    private(set) var activeName: String?
    private(set) var presets: [String] = []
    private(set) var presetEvent: PresetEvent?

    private let sourcePosition = 0

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
        sourceSlot = presetProvider.disabledSlot
    }

    func refreshSetup() async {
        await applyUnmet(setupChecker.check())
    }

    func acknowledgePresetEvent() {
        presetEvent = nil
    }

    func loadComponent(_ component: AudioUnitComponent) async {
        await load(component: component, state: nil, isBypassed: false)
    }

    func unloadComponent() async {
        await engine.unload(at: sourcePosition)
        sourceSlot = .empty(isEnabled: true)
        content = .empty
    }

    func setSourceBypassed(_ isBypassed: Bool) {
        sourceSlot = sourceSlot.applyingBypass(isBypassed)
    }

    func loadInsert(_ component: AudioUnitComponent, at index: Int) async {
        inserts[index] = .loading(component: component)
        do {
            let audioUnit = try await engine.load(component: component, state: nil, at: insertPosition(index))
            inserts[index] = .loaded(audioUnit: audioUnit, isBypassed: false)
        } catch {
            inserts[index] = .empty(isEnabled: true)
        }
    }

    func unloadInsert(at index: Int) async {
        await engine.unload(at: insertPosition(index))
        inserts[index] = .empty(isEnabled: true)
    }

    func setInsertBypassed(_ isBypassed: Bool, at index: Int) {
        inserts[index] = inserts[index].applyingBypass(isBypassed)
    }

    func selectPreset(name: String) async {
        presetProvider.setActive(name)
        activeName = name
        await loadActivePreset()
    }

    func saveCurrentPreset() {
        guard let activeName, let preset = preset(named: activeName) else { return }
        presetProvider.save(preset)
        presets = presetProvider.presets
        presetEvent = PresetEvent(id: UUID(), kind: .saved)
    }

    func restoreActivePreset() async {
        guard let activeName,
              let saved = presetProvider.load(name: activeName) else { return }
        await load(saved.source)
        if case .loaded = content {
            presetEvent = PresetEvent(id: UUID(), kind: .restored)
        }
    }

    func saveAsNewPreset(name: String) {
        guard let preset = preset(named: name) else { return }
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
            sourceSlot = presetProvider.disabledSlot
            setEmptyInsertsEnabled(false)
            return
        }
        switch content {
        case .idle, .unmet:
            setEmptyInsertsEnabled(true)
            activeName = presetProvider.activeName
            await loadActivePreset()
        case .loading, .empty, .loaded, .failed:
            break
        }
    }

    private func loadActivePreset() async {
        guard let active = activeName else {
            sourceSlot = .empty(isEnabled: true)
            content = .empty
            return
        }
        guard let preset = presetProvider.load(name: active) else {
            sourceSlot = .empty(isEnabled: true)
            content = .failed("Couldn't load this preset.")
            return
        }
        await load(preset.source)
    }

    private func load(_ slot: Preset.PluginSlot?) async {
        guard let slot else {
            sourceSlot = .empty(isEnabled: true)
            content = .empty
            return
        }
        guard slot.isInstalled else {
            sourceSlot = .disabled(component: slot.component)
            content = .failed("Couldn't load this preset.")
            return
        }
        await load(component: slot.component, state: slot.state, isBypassed: slot.isBypassed)
    }

    private func load(component: AudioUnitComponent, state: Data?, isBypassed: Bool) async {
        sourceSlot = .loading(component: component)
        content = .loading
        do {
            let audioUnit = try await engine.load(component: component, state: state, at: sourcePosition)
            audioUnit.isBypassed = isBypassed
            finishLoad(.loaded(audioUnit), slot: .loaded(audioUnit: audioUnit, isBypassed: isBypassed))
        } catch {
            finishLoad(.failed(error.message), slot: .empty(isEnabled: true))
        }
    }

    private func finishLoad(_ result: HostContent, slot: PluginSlotContent) {
        guard case .loading = content else { return }
        content = result
        sourceSlot = slot
    }

    private func insertPosition(_ index: Int) -> Int {
        sourcePosition + 1 + index
    }

    private func setEmptyInsertsEnabled(_ isEnabled: Bool) {
        inserts = inserts.map { slot in
            guard case .empty = slot else { return slot }
            return .empty(isEnabled: isEnabled)
        }
    }

    private func preset(named name: String) -> Preset? {
        guard case .loaded(let audioUnit, let isBypassed) = sourceSlot,
              let state = audioUnit.fullState else { return nil }
        return Preset(
            name: name,
            source: Preset.PluginSlot(component: audioUnit.component, state: state, isBypassed: isBypassed, isInstalled: true),
            inserts: []
        )
    }
}

private extension PluginSlotContent {
    func applyingBypass(_ isBypassed: Bool) -> PluginSlotContent {
        guard case .loaded(let audioUnit, _) = self else { return self }
        audioUnit.isBypassed = isBypassed
        return .loaded(audioUnit: audioUnit, isBypassed: isBypassed)
    }
}

private extension PresetProviderType {
    var disabledSlot: PluginSlotContent {
        guard let component = activeName.flatMap({ load(name: $0) })?.source?.component else { return .empty(isEnabled: false) }
        return .disabled(component: component)
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
