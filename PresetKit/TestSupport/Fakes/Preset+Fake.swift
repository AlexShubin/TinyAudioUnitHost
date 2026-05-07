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
        component: AudioUnitComponent = .fake(),
        state: Data = Data()
    ) -> Preset {
        Preset(component: component, state: state)
    }
}
