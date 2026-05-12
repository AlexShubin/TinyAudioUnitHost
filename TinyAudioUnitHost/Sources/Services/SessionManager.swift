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

enum ActivationSource: Sendable, Equatable {
    case stored
    case picked(AudioUnitComponent)
}

protocol SessionManagerType: Sendable {
    func activate(_ source: ActivationSource) async -> LoadedAudioUnit?
    func save() async
}

final actor SessionManager: SessionManagerType {
    private let presetProvider: PresetProviderType
    private let engine: EngineType
    private var current: LoadedAudioUnit?

    init(presetProvider: PresetProviderType, engine: EngineType) {
        self.presetProvider = presetProvider
        self.engine = engine
    }

    func activate(_ source: ActivationSource) async -> LoadedAudioUnit? {
        switch source {
        case .stored:
            guard let saved = await presetProvider.loadDefault() else { return nil }
            return await load(component: saved.component, state: saved.state)
        case .picked(let component):
            return await load(component: component, state: nil)
        }
    }

    func save() async {
        guard let preset = currentPreset() else { return }
        await presetProvider.saveDefault(preset)
    }

    private func load(component: AudioUnitComponent, state: Data?) async -> LoadedAudioUnit? {
        guard let loaded = await engine.load(component: component, state: state) else { return nil }
        current = loaded
        return loaded
    }

    private func currentPreset() -> Preset? {
        guard let current, let state = current.audioUnit.fullState else { return nil }
        return Preset(component: current.component, state: state)
    }
}
