//
//  SessionHardwareSettings+Fake.swift
//  SessionKitTests
//
//  Created by Alex Shubin on 16.10.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

@testable import SessionKit

extension SessionHardwareSettings.Audio {
    static func fake(
        deviceID: UInt32 = 1,
        inputDevice: Device? = nil,
        outputDevice: Device? = nil,
        inputChannels: [UInt32] = [],
        outputChannels: [UInt32] = []
    ) -> Self {
        Self(
            deviceID: deviceID,
            inputDevice: inputDevice,
            outputDevice: outputDevice,
            inputChannels: inputChannels,
            outputChannels: outputChannels
        )
    }
}

extension SessionHardwareSettings.Audio.Device {
    static func fake(id: UInt32 = 1, outputChannelCount: Int = 2) -> Self {
        Self(id: id, outputChannelCount: outputChannelCount)
    }
}

extension SessionHardwareSettings.Midi {
    static func fake(sources: Set<UInt32> = []) -> Self {
        Self(sources: sources)
    }
}
