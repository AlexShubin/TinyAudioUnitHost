//
//  Preset+Fake.swift
//  PresetKitTestSupport
//
//  Created by Alex Shubin on 05.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioUnitsKit
import AudioUnitsKitTestSupport
import Foundation
@testable import PresetKit

public extension Preset {
    static func fake(
        name: String = "test",
        source: PluginSlot? = .fake(),
        inserts: [PluginSlot?] = []
    ) -> Preset {
        Preset(name: name, source: source, inserts: inserts)
    }
}

public extension Preset.PluginSlot {
    static func fake(
        plugin: Plugin = .installed(.fake()),
        state: Data = Data(),
        isBypassed: Bool = false
    ) -> Preset.PluginSlot {
        Preset.PluginSlot(plugin: plugin, state: state, isBypassed: isBypassed)
    }
}

public extension Preset.PluginSlot.Missing {
    static func fake(
        name: String = "Missing AU",
        manufacturer: String = "FakeCo",
        componentType: UInt32 = 0,
        componentSubType: UInt32 = 0,
        componentManufacturer: UInt32 = 0
    ) -> Preset.PluginSlot.Missing {
        Preset.PluginSlot.Missing(
            name: name,
            manufacturer: manufacturer,
            componentType: componentType,
            componentSubType: componentSubType,
            componentManufacturer: componentManufacturer
        )
    }
}
