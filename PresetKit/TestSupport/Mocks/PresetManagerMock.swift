//
//  PresetManagerMock.swift
//  PresetKitTestSupport
//
//  Created by Alex Shubin on 08.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioUnitsKit
import PresetKit

public actor PresetManagerMock: PresetManagerType {
    public enum Calls: Equatable, Sendable {
        case load
        case save(LoadedAudioUnit)
    }

    public private(set) var calls: [Calls] = []
    public var preset: Preset?

    public init(preset: Preset? = nil) {
        self.preset = preset
    }

    public func load() -> Preset? {
        calls.append(.load)
        return preset
    }

    public func save(_ loaded: LoadedAudioUnit) {
        calls.append(.save(loaded))
    }

    public func setPreset(_ value: Preset?) {
        preset = value
    }
}
