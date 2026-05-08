//
//  PresetManager.swift
//  PresetKit
//
//  Created by Alex Shubin on 08.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioUnitsKit
import StorageKit

public protocol PresetManagerType: Sendable {
    func load() async -> Preset?
    func save(_ loaded: LoadedAudioUnit) async
}

final actor PresetManager: PresetManagerType {
    private static let presetName = "default"

    private let rawStore: RawPresetStoreType
    private let library: AudioUnitComponentsLibraryType

    init(rawStore: RawPresetStoreType, library: AudioUnitComponentsLibraryType) {
        self.rawStore = rawStore
        self.library = library
    }

    func load() async -> Preset? {
        guard let raw = await rawStore.load(name: Self.presetName),
              let component = resolve(raw) else { return nil }
        return Preset(component: component, state: raw.state)
    }

    func save(_ loaded: LoadedAudioUnit) async {
        guard let state = loaded.audioUnit.fullState else { return }
        let preset = Preset(component: loaded.component, state: state)
        await rawStore.save(raw(from: preset), name: Self.presetName)
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
