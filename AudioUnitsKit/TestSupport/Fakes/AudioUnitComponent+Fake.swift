//
//  AudioUnitComponent+Fake.swift
//  AudioUnitsKitTestSupport
//
//  Created by Alex Shubin on 04.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioToolbox
import AudioUnitsKit

public extension AudioUnitComponent {
    static func fake(
        id: ID = .fakeEffect,
        name: String = "Fake AU",
        manufacturer: String = "FakeCo"
    ) -> AudioUnitComponent {
        AudioUnitComponent(id: id, name: name, manufacturer: manufacturer)
    }
}

public extension AudioUnitComponent.ID {
    static let fakeEffect = AudioUnitComponent.ID(
        type: kAudioUnitType_Effect,
        subType: kAudioUnitSubType_DynamicsProcessor,
        manufacturer: kAudioUnitManufacturer_Apple
    )
}
