//
//  SessionHardwareSettings+Fake.swift
//  SessionKitTestSupport
//
//  Created by Alex Shubin on 17.10.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import SessionKit

public extension SessionHardwareSettings {
    static func fake(audio: Audio = .fake(), midi: Midi = .fake()) -> Self {
        Self(audio: audio, midi: midi)
    }
}

public extension SessionHardwareSettings.Audio {
    static func fake(
        deviceID: UInt32 = 1,
        inputDevice: Device? = nil,
        outputDevice: Device? = nil,
        inputChannels: [UInt32] = [],
        outputChannels: [UInt32] = [],
        sampleRate: Float64? = nil
    ) -> Self {
        Self(
            deviceID: deviceID,
            inputDevice: inputDevice,
            outputDevice: outputDevice,
            inputChannels: inputChannels,
            outputChannels: outputChannels,
            sampleRate: sampleRate
        )
    }
}

public extension SessionHardwareSettings.Audio.Device {
    static func fake(id: UInt32 = 1, outputChannelCount: Int = 2) -> Self {
        Self(id: id, outputChannelCount: outputChannelCount)
    }
}

public extension SessionHardwareSettings.Midi {
    static func fake(sources: Set<UInt32> = []) -> Self {
        Self(sources: sources)
    }
}
