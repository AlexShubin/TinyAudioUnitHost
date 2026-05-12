//
//  PresetProviderMock.swift
//  PresetKitTestSupport
//
//  Created by Alex Shubin on 09.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import PresetKit

public actor PresetProviderMock: PresetProviderType {
    public enum Calls: Equatable, Sendable {
        case loadDefault
        case saveDefault(Preset)
    }

    public private(set) var calls: [Calls] = []
    public var defaultPreset: Preset?

    public init(defaultPreset: Preset? = nil) {
        self.defaultPreset = defaultPreset
    }

    public func loadDefault() -> Preset? {
        calls.append(.loadDefault)
        return defaultPreset
    }

    public func saveDefault(_ preset: Preset) {
        defaultPreset = preset
        calls.append(.saveDefault(preset))
    }

    public func setDefaultPreset(_ value: Preset?) {
        defaultPreset = value
    }
}
