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
    static func fake(slots: [Slot?] = [.fake()]) -> Preset {
        Preset(slots: slots)
    }
}

public extension Preset.Slot {
    static func fake(
        component: AudioUnitComponent = .fake(),
        state: Data? = Data(),
        isBypassed: Bool = false,
        isInstalled: Bool = true
    ) -> Preset.Slot {
        Preset.Slot(component: component, state: state, isBypassed: isBypassed, isInstalled: isInstalled)
    }
}
