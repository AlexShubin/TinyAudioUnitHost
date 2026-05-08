//
//  LoadedAudioUnit+Fake.swift
//  AudioUnitsKitTestSupport
//
//  Created by Alex Shubin on 04.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioUnitsKit
import Foundation

public extension LoadedAudioUnit {
    static func fake(
        component: AudioUnitComponent = .fake(),
        audioUnit: AUAudioUnitType = AUAudioUnitMock(fullState: Data())
    ) -> LoadedAudioUnit {
        LoadedAudioUnit(component: component, audioUnit: audioUnit)
    }
}
