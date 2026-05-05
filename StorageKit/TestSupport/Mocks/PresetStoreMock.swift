//
//  PresetStoreMock.swift
//  StorageKitTestSupport
//
//  Created by Alex Shubin on 05.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import StorageKit

public actor PresetStoreMock: PresetStoreType {
    public enum Calls: Equatable, Sendable {
        case load(name: String)
        case save(Preset, name: String)
    }

    public private(set) var calls: [Calls] = []
    public var presets: [String: Preset]

    public init(presets: [String: Preset] = [:]) {
        self.presets = presets
    }

    public func load(name: String) -> Preset? {
        calls.append(.load(name: name))
        return presets[name]
    }

    public func save(_ preset: Preset, name: String) {
        presets[name] = preset
        calls.append(.save(preset, name: name))
    }

    public func setPresets(_ value: [String: Preset]) {
        presets = value
    }
}
