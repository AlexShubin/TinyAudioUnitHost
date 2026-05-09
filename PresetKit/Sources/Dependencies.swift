//
//  Dependencies.swift
//  PresetKit
//
//  Created by Alex Shubin on 05.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioUnitsKit
import EngineKit
import StorageKit

public struct Dependencies: Sendable {
    public let presetManager: PresetManagerType

    public static let live = Dependencies(
        presetManager: PresetManager(
            engine: EngineKit.Dependencies.live.engine,
            rawStore: StorageKit.Dependencies.live.rawPresetStore,
            library: AudioUnitsKit.Dependencies.live.audioUnitComponentsLibrary
        )
    )
}
