//
//  SessionPersister.swift
//  TinyAudioUnitHost
//
//  Created by Alex Shubin on 07.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import EngineKit
import PresetKit

protocol SessionPersisterType: Sendable {
    func setCurrent(_ loaded: LoadedAudioUnit?) async
    func persistSession() async
}

actor SessionPersister: SessionPersisterType {
    private let presetProvider: PresetProviderType
    private var current: LoadedAudioUnit?

    init(presetProvider: PresetProviderType) {
        self.presetProvider = presetProvider
    }

    func setCurrent(_ loaded: LoadedAudioUnit?) {
        current = loaded
    }

    func persistSession() async {
        guard let current, let state = current.audioUnit.fullState else { return }
        await presetProvider.save(
            Preset(component: current.component, state: state),
            slot: .session
        )
    }
}
