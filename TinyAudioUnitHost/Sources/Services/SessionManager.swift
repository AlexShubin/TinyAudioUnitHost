//
//  SessionManager.swift
//  TinyAudioUnitHost
//
//  Created by Alex Shubin on 09.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioUnitsKit
import EngineKit
import PresetKit

protocol SessionManagerType: Sendable {
    /// Yields the current modified flag every time it changes (preset load,
    /// component swap, parameter change, save).
    var isModifiedStream: AsyncStream<Bool> { get }

    /// Loads the active preset on launch — session if present, otherwise the
    /// saved default — engine-loads the AU, observes parameter changes.
    /// Sets the modified flag accordingly. Returns the loaded AU on success.
    func load() async -> LoadedAudioUnit?

    /// Engine-loads a freshly picked component as the new current AU and
    /// marks the state modified.
    func setCurrent(_ component: AudioUnitComponent) async -> LoadedAudioUnit?

    /// User-initiated save. Writes the current AU's state to the default
    /// preset, deletes any session, clears the modified flag.
    func save() async

    /// Quit-time persistence. If modified, writes the current AU's state to
    /// the session file; otherwise deletes the session file.
    func persistSession() async
}

final actor SessionManager: SessionManagerType {
    nonisolated let isModifiedStream: AsyncStream<Bool>
    private let continuation: AsyncStream<Bool>.Continuation

    private let presetProvider: PresetProviderType
    private let engine: EngineType
    private var current: LoadedAudioUnit?
    private var isModified: Bool = false
    private var observationTask: Task<Void, Never>?

    init(presetProvider: PresetProviderType, engine: EngineType) {
        self.presetProvider = presetProvider
        self.engine = engine
        let (stream, continuation) = AsyncStream<Bool>.makeStream()
        self.isModifiedStream = stream
        self.continuation = continuation
    }

    deinit {
        continuation.finish()
        observationTask?.cancel()
    }

    func load() async -> LoadedAudioUnit? {
        if let session = await presetProvider.loadSession() {
            return await activate(session, isModified: true)
        }
        if let saved = await presetProvider.loadDefault() {
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
        await presetProvider.saveDefault(preset)
        setIsModified(false)
    }

    func persistSession() async {
        if isModified, let preset = currentPreset() {
            await presetProvider.saveSession(preset)
        } else {
            await presetProvider.deleteSession()
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
}
