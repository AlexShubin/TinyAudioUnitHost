//
//  LoadedAudioUnit+Fake.swift
//  EngineKitTestSupport
//
//  Created by Alex Shubin on 04.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioUnitsKit
import AudioUnitsKitTestSupport
import CoreAudioKit
import EngineKit

public extension LoadedAudioUnit {
    static func fake(component: AudioUnitComponent = .fake()) -> LoadedAudioUnit {
        // Apple's DynamicsProcessor is built into the system, so this
        // synchronous instantiation succeeds without a network/cache.
        let auAudioUnit = try! AUAudioUnit(componentDescription: .fakeEffect)
        return LoadedAudioUnit(component: component, auAudioUnit: auAudioUnit)
    }
}
