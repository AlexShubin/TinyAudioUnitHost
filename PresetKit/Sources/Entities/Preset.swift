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
        public let component: AudioUnitComponent
        public let state: Data
        public let isBypassed: Bool
        public let isInstalled: Bool

        public init(component: AudioUnitComponent, state: Data, isBypassed: Bool, isInstalled: Bool) {
            self.component = component
            self.state = state
            self.isBypassed = isBypassed
            self.isInstalled = isInstalled
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
