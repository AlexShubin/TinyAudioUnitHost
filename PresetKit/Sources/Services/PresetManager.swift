//
//  PresetManager.swift
//  PresetKit
//
//  Created by Alex Shubin on 08.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioUnitsKit
import EngineKit
import StorageKit

public protocol PresetManagerType: Sendable {
    /// Yields the current modified flag every time it changes (preset load,
    /// component swap, parameter change, save).
    var isModifiedStream: AsyncStream<Bool> { get }

    /// Loads the active preset on launch — session if present, otherwise the
    /// saved default — engine-loads the AU, and starts observing parameter
    /// changes. Sets the modified flag accordingly (true for session, false
    /// for default). Returns the loaded AU on success.
    func load() async -> LoadedAudioUnit?

    /// Engine-loads a freshly picked component as the new current AU and
    /// marks the state modified.
    func setCurrent(_ component: AudioUnitComponent) async -> LoadedAudioUnit?

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

    nonisolated let isModifiedStream: AsyncStream<Bool>
    private let continuation: AsyncStream<Bool>.Continuation

    private let engine: EngineType
    private let rawStore: RawPresetStoreType
    private let library: AudioUnitComponentsLibraryType
    private var current: LoadedAudioUnit?
    private var isModified: Bool = false
    private var observationTask: Task<Void, Never>?

    init(
        engine: EngineType,
        rawStore: RawPresetStoreType,
        library: AudioUnitComponentsLibraryType
    ) {
        self.engine = engine
        self.rawStore = rawStore
        self.library = library
        let (stream, continuation) = AsyncStream<Bool>.makeStream()
        self.isModifiedStream = stream
        self.continuation = continuation
    }

    deinit {
        continuation.finish()
        observationTask?.cancel()
    }

    func load() async -> LoadedAudioUnit? {
        if let session = await loadResolved(name: Self.sessionName) {
            return await activate(session, isModified: true)
        }
        if let saved = await loadResolved(name: Self.defaultName) {
            return await activate(saved, isModified: false)
        }
        return nil
    }

    func setCurrent(_ component: AudioUnitComponent) async -> LoadedAudioUnit? {
        guard let loaded = await engine.load(component: component, state: nil) else { return nil }
        attach(loaded)
        setIsModified(true)
        return loaded
    }

    func save() async {
        guard let preset = currentPreset() else { return }
        await rawStore.save(raw(from: preset), name: Self.defaultName)
        await rawStore.delete(name: Self.sessionName)
        setIsModified(false)
    }

    func persistSession() async {
        if isModified, let preset = currentPreset() {
            await rawStore.save(raw(from: preset), name: Self.sessionName)
        } else {
            await rawStore.delete(name: Self.sessionName)
        }
    }

    private func activate(_ preset: Preset, isModified: Bool) async -> LoadedAudioUnit? {
        guard let loaded = await engine.load(component: preset.component, state: preset.state) else { return nil }
        attach(loaded)
        setIsModified(isModified)
        return loaded
    }

    private func attach(_ loaded: LoadedAudioUnit) {
        current = loaded
        observationTask?.cancel()
        observationTask = Task { [weak self, audioUnit = loaded.audioUnit] in
            for await _ in audioUnit.modifications {
                await self?.setIsModified(true)
            }
        }
    }

    private func setIsModified(_ value: Bool) {
        isModified = value
        continuation.yield(value)
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
