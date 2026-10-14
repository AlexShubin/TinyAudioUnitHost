//
//  PresetProvider.swift
//  PresetKit
//
//  Created by Alex Shubin on 09.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioUnitsKit
import Foundation
import StorageKit

public protocol PresetProviderType: Sendable {
    var presets: [String] { get }
    var activeName: String? { get }
    func setActive(_ name: String?)
    func load(name: String) -> Preset?
    func save(_ preset: Preset)
    func rename(from: String, to: String)
    func delete(name: String)
}

struct PresetProvider: PresetProviderType {
    private let rawStore: RawPresetStoreType
    private let library: AudioUnitComponentsLibraryType

    init(
        rawStore: RawPresetStoreType,
        library: AudioUnitComponentsLibraryType
    ) {
        self.rawStore = rawStore
        self.library = library
    }

    var presets: [String] {
        rawStore.names
    }

    var activeName: String? {
        rawStore.activePreset?.name
    }

    func setActive(_ name: String?) {
        if let name {
            rawStore.saveActivePreset(RawActivePresetState(name: name))
        } else {
            rawStore.deleteActivePreset()
        }
    }

    func load(name: String) -> Preset? {
        rawStore.load(name: name).map { domainPreset(from: $0, name: name) }
    }

    func save(_ preset: Preset) {
        rawStore.save(preset.raw, name: preset.name)
    }

    func rename(from oldName: String, to newName: String) {
        let activeWasOld = rawStore.activePreset?.name == oldName
        rawStore.rename(from: oldName, to: newName)
        if activeWasOld {
            rawStore.saveActivePreset(RawActivePresetState(name: newName))
        }
    }

    func delete(name: String) {
        let activeMatched = rawStore.activePreset?.name == name
        rawStore.delete(name: name)
        if activeMatched {
            rawStore.deleteActivePreset()
        }
    }

    private func domainPreset(from raw: RawPreset, name: String) -> Preset {
        Preset(name: name, pluginSlots: raw.pluginSlots.map { $0.map(domainSlot(from:)) })
    }

    private func domainSlot(from raw: RawPreset.PluginSlot) -> Preset.PluginSlot {
        let installed = library.components.first { $0.id == raw.componentID }
        return Preset.PluginSlot(
            component: installed ?? AudioUnitComponent(id: raw.componentID, name: raw.name, manufacturer: raw.manufacturer),
            state: raw.state,
            isBypassed: raw.isBypassed,
            isInstalled: installed != nil
        )
    }
}

private extension Preset {
    var raw: RawPreset {
        RawPreset(pluginSlots: pluginSlots.map { $0.map(\.raw) })
    }
}

private extension Preset.PluginSlot {
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
