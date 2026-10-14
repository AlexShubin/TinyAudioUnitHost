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
import PresetKit

public extension Preset {
    static func fake(
        name: String = "test",
        pluginSlots: [PluginSlot?] = [.fake()]
    ) -> Preset {
        Preset(name: name, pluginSlots: pluginSlots)
    }
}

public extension Preset.PluginSlot {
    static func fake(
        component: AudioUnitComponent = .fake(),
        state: Data? = Data(),
        isBypassed: Bool = false,
        isInstalled: Bool = true
    ) -> Preset.PluginSlot {
        Preset.PluginSlot(component: component, state: state, isBypassed: isBypassed, isInstalled: isInstalled)
    }
}
