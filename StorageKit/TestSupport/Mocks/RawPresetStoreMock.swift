//
//  RawPresetStoreMock.swift
//  StorageKitTestSupport
//
//  Created by Alex Shubin on 05.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import StorageKit

public actor RawPresetStoreMock: RawPresetStoreType {
    public enum Calls: Equatable, Sendable {
        case load(name: String)
        case save(RawPreset, name: String)
    }

    public private(set) var calls: [Calls] = []
    public var presets: [String: RawPreset]

    public init(presets: [String: RawPreset] = [:]) {
        self.presets = presets
    }

    public func load(name: String) -> RawPreset? {
        calls.append(.load(name: name))
        return presets[name]
    }

    public func save(_ preset: RawPreset, name: String) {
        presets[name] = preset
        calls.append(.save(preset, name: name))
    }

    public func setPresets(_ value: [String: RawPreset]) {
        presets = value
    }
}
