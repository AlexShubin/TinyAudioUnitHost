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
    /// Reads the in-progress session preset, if any.
    func loadSession() async -> Preset?
    /// Writes the default preset and removes any session.
    func saveDefault(_ preset: Preset) async
    /// Writes the session preset.
    func saveSession(_ preset: Preset) async
    /// Removes the session file.
    func deleteSession() async
}

final actor PresetProvider: PresetProviderType {
    private static let defaultName = "default"
    private static let sessionName = "raw_session"

    private let rawStore: RawPresetStoreType
    private let library: AudioUnitComponentsLibraryType

    init(rawStore: RawPresetStoreType, library: AudioUnitComponentsLibraryType) {
        self.rawStore = rawStore
        self.library = library
    }

    func loadDefault() async -> Preset? {
        await loadResolved(name: Self.defaultName)
    }

    func loadSession() async -> Preset? {
        await loadResolved(name: Self.sessionName)
    }

    func saveDefault(_ preset: Preset) async {
        await rawStore.save(raw(from: preset), name: Self.defaultName)
        await rawStore.delete(name: Self.sessionName)
    }

    func saveSession(_ preset: Preset) async {
        await rawStore.save(raw(from: preset), name: Self.sessionName)
    }

    func deleteSession() async {
        await rawStore.delete(name: Self.sessionName)
    }

    private func loadResolved(name: String) async -> Preset? {
        guard let raw = await rawStore.load(name: name),
              let component = resolve(raw) else { return nil }
        return Preset(component: component, state: raw.state)
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
