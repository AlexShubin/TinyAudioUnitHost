//
//  PresetsModel.swift
//  PresetKit
//
//  Created by Alex Shubin on 09.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioUnitsKit
import Foundation
import Observation
import StorageKit

@MainActor
public protocol PresetsModelType: AnyObject, Observable, Sendable {
    var names: [String] { get }
    var activeName: String? { get }
    var event: PresetEvent? { get }
    var delegate: PresetsModelDelegate? { get set }

    func load() async
    func select(name: String) async
    func saveCurrent(preset: Preset)
    func restoreActive() async
    func saveAsNew(name: String, preset: Preset)
    func rename(from: String, to: String)
    func delete(name: String)
    func acknowledgeEvent()
}

@MainActor
public protocol PresetsModelDelegate: AnyObject {
    func presetsDidActivate(preset: Preset) async
}

@MainActor @Observable
final class PresetsModel: PresetsModelType {
    private(set) var names: [String]
    private(set) var activeName: String?
    private(set) var event: PresetEvent?

    @ObservationIgnored weak var delegate: PresetsModelDelegate?

    @ObservationIgnored private let rawStore: RawPresetStoreType
    @ObservationIgnored private let library: AudioUnitComponentsLibraryType

    init(
        rawStore: RawPresetStoreType,
        library: AudioUnitComponentsLibraryType
    ) {
        self.rawStore = rawStore
        self.library = library
        names = rawStore.names
        activeName = rawStore.activePreset?.name
    }

    func load() async {
        guard let activeName else { return }
        await delegate?.presetsDidActivate(preset: preset(named: activeName) ?? Preset(slots: []))
    }

    func select(name: String) async {
        rawStore.saveActivePreset(RawActivePresetState(name: name))
        activeName = name
        await delegate?.presetsDidActivate(preset: preset(named: name) ?? Preset(slots: []))
    }

    func saveCurrent(preset: Preset) {
        guard let activeName else { return }
        save(preset: preset, name: activeName)
    }

    func restoreActive() async {
        guard let activeName, let preset = preset(named: activeName) else { return }
        await delegate?.presetsDidActivate(preset: preset)
        event = PresetEvent(id: UUID(), kind: .restored)
    }

    func saveAsNew(name: String, preset: Preset) {
        rawStore.saveActivePreset(RawActivePresetState(name: name))
        activeName = name
        save(preset: preset, name: name)
    }

    func rename(from oldName: String, to newName: String) {
        let activeWasOld = rawStore.activePreset?.name == oldName
        rawStore.rename(from: oldName, to: newName)
        if activeWasOld {
            rawStore.saveActivePreset(RawActivePresetState(name: newName))
        }
        refreshNames()
    }

    func delete(name: String) {
        let activeMatched = rawStore.activePreset?.name == name
        rawStore.delete(name: name)
        if activeMatched {
            rawStore.deleteActivePreset()
        }
        refreshNames()
    }

    func acknowledgeEvent() {
        event = nil
    }

    private func save(preset: Preset, name: String) {
        rawStore.save(preset.raw, name: name)
        names = rawStore.names
        event = PresetEvent(id: UUID(), kind: .saved)
    }

    private func refreshNames() {
        names = rawStore.names
        activeName = rawStore.activePreset?.name
    }

    private func preset(named name: String) -> Preset? {
        rawStore.load(name: name).map { Preset(slots: $0.pluginSlots.map { $0.map(slot(from:)) }) }
    }

    private func slot(from raw: RawPreset.PluginSlot) -> Preset.Slot {
        let installed = library.components.first { $0.id == raw.componentID }
        return Preset.Slot(
            component: installed ?? AudioUnitComponent(id: raw.componentID, name: raw.name, manufacturer: raw.manufacturer),
            state: raw.state,
            isBypassed: raw.isBypassed,
            isInstalled: installed != nil
        )
    }
}

private extension Preset {
    var raw: RawPreset {
        RawPreset(pluginSlots: slots.map { $0.map(\.raw) })
    }
}

private extension Preset.Slot {
    var raw: RawPreset.PluginSlot {
        RawPreset.PluginSlot(
            componentType: component.id.type,
            componentSubType: component.id.subType,
            componentManufacturer: component.id.manufacturer,
            name: component.name,
            manufacturer: component.manufacturer,
            state: state,
            isBypassed: isBypassed
        )
    }
}

private extension RawPreset.PluginSlot {
    var componentID: AudioUnitComponent.ID {
        AudioUnitComponent.ID(type: componentType, subType: componentSubType, manufacturer: componentManufacturer)
    }
}
