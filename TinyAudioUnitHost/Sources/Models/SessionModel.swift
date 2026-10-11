//
//  SessionModel.swift
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

@MainActor
protocol SessionModelType: AnyObject, Observable, Sendable {
    var slots: [PluginSlotContent] { get }
    var selectedIndex: Int { get }
    var isBusy: Bool { get }
    var canSavePreset: Bool { get }
    var activePresetName: String? { get }
    var presets: [String] { get }
    var presetEvent: PresetEvent? { get }

    func load() async
    func acknowledgePresetEvent()
    func load(_ component: AudioUnitComponent, at index: Int) async
    func unload(at index: Int) async
    func setBypassed(_ isBypassed: Bool, at index: Int)
    func select(_ index: Int)
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

enum PluginSlotContent: Equatable {
    case empty
    case loading(component: AudioUnitComponent)
    case loaded(audioUnit: LoadedAudioUnit, isBypassed: Bool)
    case failed(component: AudioUnitComponent?, message: String)
}

@MainActor @Observable
final class SessionModel: SessionModelType {
    private(set) var slots: [PluginSlotContent] = []
    private(set) var selectedIndex = 0
    private(set) var activePresetName: String?
    private(set) var presets: [String] = []
    private(set) var presetEvent: PresetEvent?

    var isBusy: Bool {
        slots.contains { slot in
            if case .loading = slot { true } else { false }
        }
    }

    var canSavePreset: Bool {
        if case .loaded = slots.first { true } else { false }
    }

    private static let sourceIndex = 0
    private static let presetFailureMessage = "Couldn't load this preset."

    @ObservationIgnored private let engine: EngineType
    @ObservationIgnored private let presetProvider: PresetProviderType
    init(
        engine: EngineType,
        presetProvider: PresetProviderType
    ) {
        self.engine = engine
        self.presetProvider = presetProvider
        presets = presetProvider.presets
        activePresetName = presetProvider.activeName
    }

    func load() async {
        await loadActivePreset()
    }

    func acknowledgePresetEvent() {
        presetEvent = nil
    }

    func load(_ component: AudioUnitComponent, at index: Int) async {
        selectedIndex = index
        await load(component, state: nil, isBypassed: false, at: index)
    }

    func unload(at index: Int) async {
        await engine.unload(at: index)
        set(.empty, at: index)
    }

    func setBypassed(_ isBypassed: Bool, at index: Int) {
        guard slots.indices.contains(index) else { return }
        slots[index] = slots[index].applyingBypass(isBypassed)
    }

    func select(_ index: Int) {
        selectedIndex = index
    }

    func selectPreset(name: String) async {
        presetProvider.setActive(name)
        activePresetName = name
        await loadActivePreset()
    }

    func saveCurrentPreset() {
        guard let activePresetName, let preset = preset(named: activePresetName) else { return }
        presetProvider.save(preset)
        presets = presetProvider.presets
        presetEvent = PresetEvent(id: UUID(), kind: .saved)
    }

    func restoreActivePreset() async {
        guard let activePresetName,
              let saved = presetProvider.load(name: activePresetName) else { return }
        await loadSource(saved.firstPluginSlot)
        if case .loaded = slots.first {
            presetEvent = PresetEvent(id: UUID(), kind: .restored)
        }
    }

    func saveAsNewPreset(name: String) {
        guard let preset = preset(named: name) else { return }
        presetProvider.save(preset)
        presetProvider.setActive(preset.name)
        activePresetName = preset.name
        presets = presetProvider.presets
        presetEvent = PresetEvent(id: UUID(), kind: .saved)
    }

    func renamePreset(from: String, to: String) {
        presetProvider.rename(from: from, to: to)
        presets = presetProvider.presets
        activePresetName = presetProvider.activeName
    }

    func deletePreset(name: String) {
        presetProvider.delete(name: name)
        presets = presetProvider.presets
        activePresetName = presetProvider.activeName
    }

    private func loadActivePreset() async {
        guard let active = activePresetName else {
            set(.empty, at: Self.sourceIndex)
            return
        }
        guard let preset = presetProvider.load(name: active) else {
            set(.failed(component: nil, message: Self.presetFailureMessage), at: Self.sourceIndex)
            return
        }
        await loadSource(preset.firstPluginSlot)
    }

    private func loadSource(_ slot: Preset.PluginSlot?) async {
        guard let slot else {
            set(.empty, at: Self.sourceIndex)
            return
        }
        guard slot.isInstalled else {
            set(.failed(component: slot.component, message: Self.presetFailureMessage), at: Self.sourceIndex)
            return
        }
        await load(slot.component, state: slot.state, isBypassed: slot.isBypassed, at: Self.sourceIndex)
    }

    private func load(_ component: AudioUnitComponent, state: Data?, isBypassed: Bool, at index: Int) async {
        set(.loading(component: component), at: index)
        do {
            let audioUnit = try await engine.load(EnginePluginSlot(component: component, state: state), at: index)
            audioUnit.isBypassed = isBypassed
            finishLoad(.loaded(audioUnit: audioUnit, isBypassed: isBypassed), at: index)
        } catch {
            finishLoad(.failed(component: component, message: error.message), at: index)
        }
    }

    private func finishLoad(_ result: PluginSlotContent, at index: Int) {
        guard slots.indices.contains(index), case .loading = slots[index] else { return }
        set(result, at: index)
    }

    private func set(_ content: PluginSlotContent, at index: Int) {
        if index == slots.count {
            slots.append(content)
        } else {
            slots[index] = content
        }
        while slots.last == .empty {
            slots.removeLast()
        }
    }

    private func preset(named name: String) -> Preset? {
        guard case .loaded(let audioUnit, let isBypassed) = slots.first,
              let state = audioUnit.fullState else { return nil }
        return Preset(
            name: name,
            pluginSlots: [Preset.PluginSlot(component: audioUnit.component, state: state, isBypassed: isBypassed, isInstalled: true)]
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

private extension Preset {
    var firstPluginSlot: PluginSlot? {
        pluginSlots.first ?? nil
    }
}

private extension EngineLoadError {
    var message: String {
        switch self {
        case .audioUnitInstantiationFailed: return "Couldn't load this audio unit."
        }
    }
}
