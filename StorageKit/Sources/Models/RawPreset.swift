//
//  RawPreset.swift
//  StorageKit
//
//  Created by Alex Shubin on 05.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import Foundation

public struct RawPreset: Sendable, Equatable, Codable {
    public let componentType: UInt32
    public let componentSubType: UInt32
    public let componentManufacturer: UInt32
    public let state: Data

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
