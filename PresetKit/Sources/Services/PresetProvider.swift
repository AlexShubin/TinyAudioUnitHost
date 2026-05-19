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
    var presets: [Preset] { get }
    var activeName: String? { get }
    func setActive(_ name: String?)
    func load(name: String) -> Preset?
    func save(_ preset: Preset)
    func saveAs(_ preset: Preset) -> Result<Preset, PresetNameError>
    func rename(from: String, to: String) -> Result<Void, PresetNameError>
    func delete(name: String)
}

struct PresetProvider: PresetProviderType {
    private let rawStore: RawPresetStoreType
    private let library: AudioUnitComponentsLibraryType
    private let validator: PresetNameValidatorType

    init(
        rawStore: RawPresetStoreType,
        library: AudioUnitComponentsLibraryType,
        validator: PresetNameValidatorType
    ) {
        self.rawStore = rawStore
        self.library = library
        self.validator = validator
    }

    var presets: [Preset] {
        rawStore.names.compactMap { name in
            rawStore.load(name: name).flatMap { domainPreset(from: $0, name: name) }
        }
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
        rawStore.load(name: name).flatMap { domainPreset(from: $0, name: name) }
    }

    func save(_ preset: Preset) {
        rawStore.save(rawPreset(from: preset), name: preset.name)
    }

    func saveAs(_ preset: Preset) -> Result<Preset, PresetNameError> {
        if let error = validator.validate(name: preset.name, for: .saveAs) {
            return .failure(error)
        }
        rawStore.save(rawPreset(from: preset), name: preset.name)
        return .success(preset)
    }

    func rename(from oldName: String, to newName: String) -> Result<Void, PresetNameError> {
        if let error = validator.validate(name: newName, for: .rename(currentName: oldName)) {
            return .failure(error)
        }
        let activeWasOld = rawStore.activePreset?.name == oldName
        rawStore.rename(from: oldName, to: newName)
        if activeWasOld {
            rawStore.saveActivePreset(RawActivePresetState(name: newName))
        }
        return .success(())
    }

    func delete(name: String) {
        let activeMatched = rawStore.activePreset?.name == name
        rawStore.delete(name: name)
        if activeMatched {
            rawStore.deleteActivePreset()
        }
    }

    private func domainPreset(from raw: RawPreset, name: String) -> Preset? {
        guard let component = resolve(raw) else { return nil }
        return Preset(name: name, component: component, state: raw.state)
    }

    private func resolve(_ raw: RawPreset) -> AudioUnitComponent? {
        library.components.first { component in
            let desc = component.componentDescription
            return desc.componentType == raw.componentType
                && desc.componentSubType == raw.componentSubType
                && desc.componentManufacturer == raw.componentManufacturer
        }
    }

    private func rawPreset(from preset: Preset) -> RawPreset {
        let desc = preset.component.componentDescription
        return RawPreset(
            componentType: desc.componentType,
            componentSubType: desc.componentSubType,
            componentManufacturer: desc.componentManufacturer,
            state: preset.state
        )
    }
}
