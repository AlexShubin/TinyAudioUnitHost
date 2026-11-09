//
//  PluginSlot+Fake.swift
//  SessionKitTestSupport
//
//  Created by Alex Shubin on 09.11.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioUnitsKit
import AudioUnitsKitTestSupport
import Foundation
import SessionKit

public extension PluginSlot {
    static func fake(
        component: AudioUnitComponent = .fake(),
        state: Data? = Data(),
        isBypassed: Bool = false,
        isInstalled: Bool = true
    ) -> PluginSlot {
        PluginSlot(component: component, state: state, isBypassed: isBypassed, isInstalled: isInstalled)
    }
}
