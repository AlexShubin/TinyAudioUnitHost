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
    /// Returns the preset to load on launch. If a session exists on disk, it
    /// wins (and `isModified` is `true`); otherwise the saved default is
    /// returned (with `isModified` `false`).
    func load() async -> ActivePreset?

    /// Records the currently-loaded AU. The manager keeps a strong reference
    /// so it can read `fullState` at quit time even after the VM has
    /// deinit'd.
    func setCurrent(_ loaded: LoadedAudioUnit?) async

    /// Marks the in-memory state as modified. Doesn't touch disk.
    func setModified() async

    /// User-initiated save. Writes the current AU's state to the default
    /// preset, deletes any session, clears the modified flag.
    func save() async

    /// Quit-time persistence. If modified, writes the current AU's state to
    /// the session file; otherwise deletes the session file (so next launch
    /// loads the default).
    func persistSession() async
}

final actor PresetManager: PresetManagerType {
    private static let defaultName = "default"
    private static let sessionName = "raw_session"

    private let rawStore: RawPresetStoreType
    private let library: AudioUnitComponentsLibraryType
    private var current: LoadedAudioUnit?
    private var isModified: Bool = false

    init(rawStore: RawPresetStoreType, library: AudioUnitComponentsLibraryType) {
        self.rawStore = rawStore
        self.library = library
    }

    func load() async -> ActivePreset? {
        if let session = await loadResolved(name: Self.sessionName) {
            isModified = true
            return ActivePreset(preset: session, isModified: true)
        }
        if let saved = await loadResolved(name: Self.defaultName) {
            isModified = false
            return ActivePreset(preset: saved, isModified: false)
        }
        return nil
    }

    func setCurrent(_ loaded: LoadedAudioUnit?) {
        current = loaded
    }

    func setModified() {
        isModified = true
    }

    func save() async {
        guard let preset = currentPreset() else { return }
        await rawStore.save(raw(from: preset), name: Self.defaultName)
        await rawStore.delete(name: Self.sessionName)
        isModified = false
    }

    func persistSession() async {
        if isModified, let preset = currentPreset() {
            await rawStore.save(raw(from: preset), name: Self.sessionName)
        } else {
            await rawStore.delete(name: Self.sessionName)
        }
    }

    private func currentPreset() -> Preset? {
        guard let current, let state = current.audioUnit.fullState else { return nil }
        return Preset(component: current.component, state: state)
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
