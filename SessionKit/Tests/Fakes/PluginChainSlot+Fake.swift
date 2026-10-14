//
//  PluginChainSlot+Fake.swift
//  SessionKitTests
//
//  Created by Alex Shubin on 11.10.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioUnitsKit
import AudioUnitsKitTestSupport
import Foundation
@testable import SessionKit

extension PluginChainSlot {
    static func fake(
        component: AudioUnitComponent = .fake(),
        state: Data? = nil
    ) -> PluginChainSlot {
        PluginChainSlot(component: component, state: state)
    }
}
