//
//  AudioDevice+Fake.swift
//  CommonTestSupport
//
//  Created by Alex Shubin on 30.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import Common

public extension AudioDevice {
    static func fake(
        id: UInt32 = 1,
        uid: String = "uid",
        name: String = "Test Device",
        inputChannels: [AudioChannel] = [],
        outputChannels: [AudioChannel] = [],
        availableBufferSizes: [UInt32] = []
    ) -> AudioDevice {
        AudioDevice(
            id: id,
            uid: uid,
            name: name,
            inputChannels: inputChannels,
            outputChannels: outputChannels,
            availableBufferSizes: availableBufferSizes
        )
    }
}
