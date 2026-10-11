//
//  RawPreset.swift
//  StorageKit
//
//  Created by Alex Shubin on 05.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import Foundation

public struct RawPreset: Sendable, Equatable, Codable {
    public struct PluginSlot: Sendable, Equatable, Codable {
        public let componentType: UInt32
        public let componentSubType: UInt32
        public let componentManufacturer: UInt32
        public let name: String
        public let manufacturer: String
        public let state: Data
        public let isBypassed: Bool

        public init(
            componentType: UInt32,
            componentSubType: UInt32,
            componentManufacturer: UInt32,
            name: String,
            manufacturer: String,
            state: Data,
            isBypassed: Bool
        ) {
            self.componentType = componentType
            self.componentSubType = componentSubType
            self.componentManufacturer = componentManufacturer
            self.name = name
            self.manufacturer = manufacturer
            self.state = state
            self.isBypassed = isBypassed
        }
    }

    static let currentVersion = 2

    let version: Int
    public let pluginSlots: [PluginSlot?]

    public init(pluginSlots: [PluginSlot?]) {
        self.version = Self.currentVersion
        self.pluginSlots = pluginSlots
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        guard let version = try container.decodeIfPresent(Int.self, forKey: .version) else {
            self = try RawPresetV1(from: decoder).migrated
            return
        }
        self.version = version
        pluginSlots = try container.decode([PluginSlot?].self, forKey: .pluginSlots)
    }
}

// MARK: - Legacy Schemas

/// The preset file schema before versioning. Frozen: it describes files already on disk.
struct RawPresetV1: Decodable {
    let componentType: UInt32
    let componentSubType: UInt32
    let componentManufacturer: UInt32
    let state: Data

    var migrated: RawPreset {
        RawPreset(
            pluginSlots: [
                RawPreset.PluginSlot(
                    componentType: componentType,
                    componentSubType: componentSubType,
                    componentManufacturer: componentManufacturer,
                    name: "",
                    manufacturer: "",
                    state: state,
                    isBypassed: false
                )
            ]
        )
    }
}
