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
    func loadActive() async -> ActivePreset?
    func setCurrent(_ loaded: LoadedAudioUnit?) async
    func save() async
    func persistSession() async
}

final actor PresetManager: PresetManagerType {
    private static let defaultName = "default"
    private static let sessionName = "raw_session"

    private let rawStore: RawPresetStoreType
    private let library: AudioUnitComponentsLibraryType
    private var current: LoadedAudioUnit?

    init(rawStore: RawPresetStoreType, library: AudioUnitComponentsLibraryType) {
        self.rawStore = rawStore
        self.library = library
    }

    func loadActive() async -> ActivePreset? {
        let session = await loadPreset(name: Self.sessionName)
        let saved = await loadPreset(name: Self.defaultName)
        guard let active = session ?? saved else { return nil }
        let isModified = session != nil && session != saved
        return ActivePreset(preset: active, isModified: isModified)
    }

    func setCurrent(_ loaded: LoadedAudioUnit?) {
        current = loaded
    }

    func save() async {
        guard let current, let state = current.audioUnit.fullState else { return }
        let preset = Preset(component: current.component, state: state)
        await savePreset(preset, name: Self.defaultName)
        await savePreset(preset, name: Self.sessionName)
    }

    func persistSession() async {
        guard let current, let state = current.audioUnit.fullState else { return }
        await savePreset(Preset(component: current.component, state: state), name: Self.sessionName)
    }

    private func loadPreset(name: String) async -> Preset? {
        guard let raw = await rawStore.load(name: name),
              let component = resolve(raw) else { return nil }
        return Preset(component: component, state: raw.state)
    }

    private func savePreset(_ preset: Preset, name: String) async {
        await rawStore.save(raw(from: preset), name: name)
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
