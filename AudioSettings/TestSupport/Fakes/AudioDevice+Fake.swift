//
//  AudioDevice+Fake.swift
//  AudioSettingsTestSupport
//
//  Created by Alex Shubin on 30.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioSettings

public extension AudioDevice {
    static func fake(
        id: UInt32 = 1,
        uid: String = "uid",
        name: String = "Test Device",
        inputChannels: [AudioChannel] = [],
        outputChannels: [AudioChannel] = [],
        availableBufferSizes: [UInt32] = [],
        availableSampleRates: [Float64] = []
    ) -> AudioDevice {
        AudioDevice(
            id: id,
            uid: uid,
            name: name,
            inputChannels: inputChannels,
            outputChannels: outputChannels,
            availableBufferSizes: availableBufferSizes,
            availableSampleRates: availableSampleRates
        )
    }
}
