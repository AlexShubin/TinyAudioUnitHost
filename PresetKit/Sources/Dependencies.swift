//
//  Dependencies.swift
//  PresetKit
//
//  Created by Alex Shubin on 05.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioUnitsKit
import StorageKit

public struct Dependencies: Sendable {
    public let presetProvider: PresetProviderType

    public static let live = Dependencies(
        presetProvider: PresetProvider(
            rawStore: StorageKit.Dependencies.live.rawPresetStore,
            library: AudioUnitsKit.Dependencies.live.audioUnitComponentsLibrary
        )
    )
}
