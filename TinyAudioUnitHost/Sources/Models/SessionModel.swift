//
//  SessionModel.swift
//  TinyAudioUnitHost
//
//  Created by Alex Shubin on 20.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioUnitsKit
import Foundation
import Observation
import PresetKit
import SessionKit

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
    case failed(component: AudioUnitComponent, state: Data?, isBypassed: Bool, message: String)
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
        !isBusy && slots.contains { slot in
            if case .loaded = slot { true } else { false }
        }
    }

    @ObservationIgnored private let pluginChain: PluginChainType
    @ObservationIgnored private let presetProvider: PresetProviderType
    init(
        pluginChain: PluginChainType,
        presetProvider: PresetProviderType
    ) {
        self.pluginChain = pluginChain
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
        replaceSlot(at: index, with: .loading(component: component))
        do {
            let audioUnit = try await pluginChain.load(PluginChainSlot(component: component, state: nil), at: index)
            finishLoadingSlot(at: index, with: .loaded(audioUnit: audioUnit, isBypassed: false))
        } catch {
            finishLoadingSlot(at: index, with: .failed(component: component, state: nil, isBypassed: false, message: error.message))
        }
    }

    func unload(at index: Int) async {
        replaceSlot(at: index, with: .empty)
        await pluginChain.unload(at: index)
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
        await loadPreset(saved)
        if !slots.contains(where: \.isFailed) {
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
        guard let activePresetName else { return }
        let preset = presetProvider.load(name: activePresetName) ?? Preset(name: activePresetName, pluginSlots: [])
        await loadPreset(preset)
    }

    private func loadPreset(_ preset: Preset) async {
        replaceSlots(with: preset.pluginSlots.map { $0?.initialContent ?? .empty })
        let chainSlots = preset.pluginSlots.map { $0?.chainSlot }
        let results = await pluginChain.load(chainSlots)
        for (index, (pluginSlot, result)) in zip(preset.pluginSlots, results).enumerated() {
            guard let pluginSlot, let result else { continue }
            finishLoadingSlot(at: index, with: pluginSlot.content(for: result))
        }
    }

    private func finishLoadingSlot(at index: Int, with content: PluginSlotContent) {
        guard slots.indices.contains(index), case .loading = slots[index] else { return }
        replaceSlot(at: index, with: content)
    }

    private func replaceSlot(at index: Int, with content: PluginSlotContent) {
        guard index <= slots.count else { return }
        var updated = slots
        if index == updated.count {
            updated.append(content)
        } else {
            updated[index] = content
        }
        replaceSlots(with: updated)
    }

    private func replaceSlots(with contents: [PluginSlotContent]) {
        var trimmed = contents
        while trimmed.last == .empty {
            trimmed.removeLast()
        }
        slots = trimmed
        selectFilledSlotIfNeeded()
    }

    private func selectFilledSlotIfNeeded() {
        let selected = slots.indices.contains(selectedIndex) ? slots[selectedIndex] : .empty
        guard selected == .empty, let firstFilled = slots.firstIndex(where: { $0 != .empty }) else { return }
        selectedIndex = firstFilled
    }

    private func preset(named name: String) -> Preset? {
        guard canSavePreset else { return nil }
        let pluginSlots = slots.map { slot -> Preset.PluginSlot? in
            switch slot {
            case .empty, .loading:
                nil
            case .loaded(let audioUnit, let isBypassed):
                Preset.PluginSlot(component: audioUnit.component, state: audioUnit.fullState, isBypassed: isBypassed, isInstalled: true)
            case .failed(let component, let state, let isBypassed, _):
                Preset.PluginSlot(component: component, state: state, isBypassed: isBypassed, isInstalled: true)
            }
        }
        return Preset(name: name, pluginSlots: pluginSlots)
    }
}

private extension PluginSlotContent {
    func applyingBypass(_ isBypassed: Bool) -> PluginSlotContent {
        guard case .loaded(let audioUnit, _) = self else { return self }
        audioUnit.isBypassed = isBypassed
        return .loaded(audioUnit: audioUnit, isBypassed: isBypassed)
    }

    var isFailed: Bool {
        if case .failed = self { true } else { false }
    }
}

private extension Preset.PluginSlot {
    static let notInstalledMessage = "This plug-in isn't installed."

    var initialContent: PluginSlotContent {
        isInstalled ? .loading(component: component) : failed(message: Self.notInstalledMessage)
    }

    var chainSlot: PluginChainSlot? {
        isInstalled ? PluginChainSlot(component: component, state: state) : nil
    }

    func content(for result: Result<LoadedAudioUnit, PluginChainLoadError>) -> PluginSlotContent {
        switch result {
        case .success(let audioUnit):
            audioUnit.isBypassed = isBypassed
            return .loaded(audioUnit: audioUnit, isBypassed: isBypassed)
        case .failure(let error):
            return failed(message: error.message)
        }
    }

    func failed(message: String) -> PluginSlotContent {
        .failed(component: component, state: state, isBypassed: isBypassed, message: message)
    }
}

private extension PluginChainLoadError {
    var message: String {
        switch self {
        case .audioUnitInstantiationFailed: return "Couldn't load this audio unit."
        }
    }
}
