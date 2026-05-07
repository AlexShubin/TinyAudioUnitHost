//
//  PresetProvider.swift
//  PresetKit
//
//  Created by Alex Shubin on 05.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioUnitsKit
import StorageKit

public protocol PresetProviderType: Sendable {
    func load(slot: PresetSlot) async -> Preset?
    func save(_ preset: Preset, slot: PresetSlot) async
}

final actor PresetProvider: PresetProviderType {
    private let rawStore: RawPresetStoreType
    private let library: AudioUnitComponentsLibraryType

    init(rawStore: RawPresetStoreType, library: AudioUnitComponentsLibraryType) {
        self.rawStore = rawStore
        self.library = library
    }

    func load(slot: PresetSlot) async -> Preset? {
        guard let raw = await rawStore.load(name: name(for: slot)),
              let component = resolve(raw) else { return nil }
        return Preset(component: component, state: raw.state)
    }

    func save(_ preset: Preset, slot: PresetSlot) async {
        await rawStore.save(raw(from: preset), name: name(for: slot))
    }

    private func name(for slot: PresetSlot) -> String {
        switch slot {
        case .session: "raw_session"
        case .default: "default"
        }
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
