//
//  SessionManager.swift
//  TinyAudioUnitHost
//
//  Created by Alex Shubin on 09.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioUnitsKit
import EngineKit
import Foundation
import PresetKit

/// Where a new "current AU" comes from.
enum ActivationSource: Sendable, Equatable {
    /// Load whatever's on disk — session (modified) wins over saved default
    /// (unmodified). Used by `.task`.
    case stored
    /// User picked this component. Always marked modified. Used by `.selected`.
    case picked(AudioUnitComponent)
}

protocol SessionManagerType: Sendable {
    /// Yields the current modified flag every time it changes (preset load,
    /// component swap, parameter change, save).
    var isModifiedStream: AsyncStream<Bool> { get }

    /// Engine-loads the AU for the given source, attaches the parameter
    /// observer, and updates the modified flag. Returns the loaded AU.
    func activate(_ source: ActivationSource) async -> LoadedAudioUnit?

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

    func activate(_ source: ActivationSource) async -> LoadedAudioUnit? {
        switch source {
        case .stored:
            if let session = await presetProvider.loadSession() {
                return await activate(component: session.component, state: session.state, isModified: true)
            }
            if let saved = await presetProvider.loadDefault() {
                return await activate(component: saved.component, state: saved.state, isModified: false)
            }
            return nil
        case .picked(let component):
            return await activate(component: component, state: nil, isModified: true)
        }
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

    private func activate(component: AudioUnitComponent, state: Data?, isModified: Bool) async -> LoadedAudioUnit? {
        guard let loaded = await engine.load(component: component, state: state) else { return nil }
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
