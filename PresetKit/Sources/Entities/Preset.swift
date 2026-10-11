//
//  Preset.swift
//  PresetKit
//
//  Created by Alex Shubin on 05.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioUnitsKit
import Foundation

public struct Preset: Sendable, Equatable {
    public struct PluginSlot: Sendable, Equatable {
        public enum Plugin: Sendable, Equatable {
            case installed(AudioUnitComponent)
            case missing(Missing)
        }

        public struct Missing: Sendable, Equatable {
            public let name: String
            public let manufacturer: String
            public let componentType: UInt32
            public let componentSubType: UInt32
            public let componentManufacturer: UInt32
        }

        public let plugin: Plugin
        public let state: Data
        public let isBypassed: Bool

        public init(plugin: Plugin, state: Data, isBypassed: Bool) {
            self.plugin = plugin
            self.state = state
            self.isBypassed = isBypassed
        }
    }

    public let name: String
    public let source: PluginSlot?
    public let inserts: [PluginSlot?]

    public init(name: String, source: PluginSlot?, inserts: [PluginSlot?]) {
        self.name = name
        self.source = source
        self.inserts = inserts
    }
}
