//
//  AudioUnitComponent+Fake.swift
//  EngineKitTestSupport
//
//  Created by Alex Shubin on 04.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioToolbox
import EngineKit

public extension AudioUnitComponent {
    static func fake(
        name: String = "Fake AU",
        manufacturer: String = "FakeCo",
        componentDescription: AudioComponentDescription = .fakeEffect
    ) -> AudioUnitComponent {
        AudioUnitComponent(
            name: name,
            manufacturer: manufacturer,
            componentDescription: componentDescription
        )
    }
}

public extension AudioComponentDescription {
    static let fakeEffect = AudioComponentDescription(
        componentType: kAudioUnitType_Effect,
        componentSubType: kAudioUnitSubType_DynamicsProcessor,
        componentManufacturer: kAudioUnitManufacturer_Apple,
        componentFlags: 0,
        componentFlagsMask: 0
    )
}
