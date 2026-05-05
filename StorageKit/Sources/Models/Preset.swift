//
//  Preset.swift
//  StorageKit
//
//  Created by Alex Shubin on 05.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import Foundation

public struct Preset: Sendable, Equatable, Codable {
    public var componentType: UInt32
    public var componentSubType: UInt32
    public var componentManufacturer: UInt32
    public var state: Data

    public init(
        componentType: UInt32,
        componentSubType: UInt32,
        componentManufacturer: UInt32,
        state: Data
    ) {
        self.componentType = componentType
        self.componentSubType = componentSubType
        self.componentManufacturer = componentManufacturer
        self.state = state
    }
}
