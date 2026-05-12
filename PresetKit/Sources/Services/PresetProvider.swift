//
//  PresetProvider.swift
//  PresetKit
//
//  Created by Alex Shubin on 09.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioUnitsKit
import StorageKit

public protocol PresetProviderType: Sendable {
    /// Reads the saved default preset, if any.
    func loadDefault() async -> Preset?
    /// Writes the default preset.
    func saveDefault(_ preset: Preset) async
}

final actor PresetProvider: PresetProviderType {
    private static let defaultName = "default"

    private let rawStore: RawPresetStoreType
    private let library: AudioUnitComponentsLibraryType

    init(rawStore: RawPresetStoreType, library: AudioUnitComponentsLibraryType) {
        self.rawStore = rawStore
        self.library = library
    }

    func loadDefault() async -> Preset? {
        guard let raw = await rawStore.load(name: Self.defaultName),
              let component = resolve(raw) else { return nil }
        return Preset(component: component, state: raw.state)
    }

    func saveDefault(_ preset: Preset) async {
        await rawStore.save(raw(from: preset), name: Self.defaultName)
    }

    private func resolve(_ raw: RawPreset) -> AudioUnitComponent? {
        library.components.first { component in
            let desc = component.componentDescription
            return desc.componentType == raw.componentType
                && desc.componentSubType == raw.componentSubType
                && desc.componentManufacturer == raw.componentManufacturer
        }
    }

    private func raw(from preset: Preset) -> RawPreset {
        let desc = preset.component.componentDescription
        return RawPreset(
            componentType: desc.componentType,
            componentSubType: desc.componentSubType,
            componentManufacturer: desc.componentManufacturer,
            state: preset.state
        )
    }
}
