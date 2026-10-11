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
        Preset(
            name: name,
            source: raw.source.map(domainSlot(from:)),
            inserts: raw.inserts.map { $0.map(domainSlot(from:)) }
        )
    }

    private func domainSlot(from raw: RawPreset.PluginSlot) -> Preset.PluginSlot {
        Preset.PluginSlot(
            plugin: resolve(raw).map(Preset.PluginSlot.Plugin.installed) ?? .missing(
                Preset.PluginSlot.Missing(
                    name: raw.name,
                    manufacturer: raw.manufacturer,
                    componentType: raw.componentType,
                    componentSubType: raw.componentSubType,
                    componentManufacturer: raw.componentManufacturer
                )
            ),
            state: raw.state,
            isBypassed: raw.isBypassed
        )
    }

    private func resolve(_ raw: RawPreset.PluginSlot) -> AudioUnitComponent? {
        library.components.first { component in
            let desc = component.componentDescription
            return desc.componentType == raw.componentType
                && desc.componentSubType == raw.componentSubType
                && desc.componentManufacturer == raw.componentManufacturer
        }
    }
}

private extension Preset {
    var raw: RawPreset {
        RawPreset(
            source: source.map(\.raw),
            inserts: inserts.map { $0.map(\.raw) }
        )
    }
}

private extension Preset.PluginSlot {
    var raw: RawPreset.PluginSlot {
        switch plugin {
        case .installed(let component):
            let desc = component.componentDescription
            return RawPreset.PluginSlot(
                componentType: desc.componentType,
                componentSubType: desc.componentSubType,
                componentManufacturer: desc.componentManufacturer,
                name: component.name,
                manufacturer: component.manufacturer,
                state: state,
                isBypassed: isBypassed
            )
        case .missing(let missing):
            return RawPreset.PluginSlot(
                componentType: missing.componentType,
                componentSubType: missing.componentSubType,
                componentManufacturer: missing.componentManufacturer,
                name: missing.name,
                manufacturer: missing.manufacturer,
                state: state,
                isBypassed: isBypassed
            )
        }
    }
}
