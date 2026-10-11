//
//  RawPreset+Fake.swift
//  StorageKitTestSupport
//
//  Created by Alex Shubin on 05.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import Foundation
import StorageKit

public extension RawPreset {
    static func fake(
        pluginSlots: [PluginSlot?] = [.fake()]
    ) -> RawPreset {
        RawPreset(pluginSlots: pluginSlots)
    }
}

public extension RawPreset.PluginSlot {
    static func fake(
        componentType: UInt32 = 0,
        componentSubType: UInt32 = 0,
        componentManufacturer: UInt32 = 0,
        name: String = "Fake AU",
        manufacturer: String = "FakeCo",
        state: Data = Data(),
        isBypassed: Bool = false
    ) -> RawPreset.PluginSlot {
        RawPreset.PluginSlot(
            componentType: componentType,
            componentSubType: componentSubType,
            componentManufacturer: componentManufacturer,
            name: name,
            manufacturer: manufacturer,
            state: state,
            isBypassed: isBypassed
        )
    }
}
