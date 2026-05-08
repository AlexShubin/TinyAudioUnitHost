//
//  ActivePreset.swift
//  PresetKit
//
//  Created by Alex Shubin on 08.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

public struct ActivePreset: Sendable, Equatable {
    public let preset: Preset
    public let isModified: Bool

    public init(preset: Preset, isModified: Bool) {
        self.preset = preset
        self.isModified = isModified
    }
}
