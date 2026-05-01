//
//  AudioUnitComponent+Fake.swift
//  EngineKitTestSupport
//
//  Created by Alex Shubin on 30.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioToolbox
import EngineKit

public extension AudioUnitComponent {
    static func fake(
        name: String = "Test Component",
        manufacturer: String = "Test Manufacturer",
        componentDescription: AudioComponentDescription = AudioComponentDescription()
    ) -> AudioUnitComponent {
        AudioUnitComponent(
            name: name,
            manufacturer: manufacturer,
            componentDescription: componentDescription
        )
    }
}
