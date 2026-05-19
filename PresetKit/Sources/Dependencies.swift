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
    public let presetNameValidator: PresetNameValidatorType

    public static let live: Dependencies = {
        let rawStore = StorageKit.Dependencies.live.rawPresetStore
        let validator = PresetNameValidator(rawStore: rawStore)
        return Dependencies(
            presetProvider: PresetProvider(
                rawStore: rawStore,
                library: AudioUnitsKit.Dependencies.live.audioUnitComponentsLibrary,
                validator: validator
            ),
            presetNameValidator: validator
        )
    }()
}
