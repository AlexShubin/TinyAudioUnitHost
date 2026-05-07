//
//  PresetProviderMock.swift
//  PresetKitTestSupport
//
//  Created by Alex Shubin on 05.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import PresetKit

public actor PresetProviderMock: PresetProviderType {
    public enum Calls: Equatable, Sendable {
        case load(slot: PresetSlot)
        case save(Preset, slot: PresetSlot)
    }

    public private(set) var calls: [Calls] = []
    public var presets: [PresetSlot: Preset]

    public init(presets: [PresetSlot: Preset] = [:]) {
        self.presets = presets
    }

    public func load(slot: PresetSlot) -> Preset? {
        calls.append(.load(slot: slot))
        return presets[slot]
    }

    public func save(_ preset: Preset, slot: PresetSlot) {
        presets[slot] = preset
        calls.append(.save(preset, slot: slot))
    }

    public func setPresets(_ value: [PresetSlot: Preset]) {
        presets = value
    }
}
