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
    func saveCurrent(chain: [PresetSlot?])
    func restoreActive() async
    func saveAsNew(name: String, chain: [PresetSlot?])
    func rename(from: String, to: String)
    func delete(name: String)
    func acknowledgeEvent()
}

@MainActor
public protocol PresetsModelDelegate: AnyObject {
    func presetsDidActivate(chain: [PresetSlot?]) async
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
        await delegate?.presetsDidActivate(chain: chain(named: activeName) ?? [])
    }

    func select(name: String) async {
        rawStore.saveActivePreset(RawActivePresetState(name: name))
        activeName = name
        await delegate?.presetsDidActivate(chain: chain(named: name) ?? [])
    }

    func saveCurrent(chain: [PresetSlot?]) {
        guard let activeName else { return }
        save(chain: chain, name: activeName)
    }

    func restoreActive() async {
        guard let activeName, let chain = chain(named: activeName) else { return }
        await delegate?.presetsDidActivate(chain: chain)
        event = PresetEvent(id: UUID(), kind: .restored)
    }

    func saveAsNew(name: String, chain: [PresetSlot?]) {
        rawStore.saveActivePreset(RawActivePresetState(name: name))
        activeName = name
        save(chain: chain, name: name)
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

    private func save(chain: [PresetSlot?], name: String) {
        rawStore.save(RawPreset(pluginSlots: chain.map { $0.map(\.raw) }), name: name)
        names = rawStore.names
        event = PresetEvent(id: UUID(), kind: .saved)
    }

    private func refreshNames() {
        names = rawStore.names
        activeName = rawStore.activePreset?.name
    }

    private func chain(named name: String) -> [PresetSlot?]? {
        rawStore.load(name: name).map { $0.pluginSlots.map { $0.map(slot(from:)) } }
    }

    private func slot(from raw: RawPreset.PluginSlot) -> PresetSlot {
        let installed = library.components.first { $0.id == raw.componentID }
        return PresetSlot(
            component: installed ?? AudioUnitComponent(id: raw.componentID, name: raw.name, manufacturer: raw.manufacturer),
            state: raw.state,
            isBypassed: raw.isBypassed,
            isInstalled: installed != nil
        )
    }
}

private extension PresetSlot {
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
