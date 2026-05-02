//
//  RawAudioSettings+Fake.swift
//  StorageKitTestSupport
//
//  Created by Alex Shubin on 30.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import StorageKit

public extension RawAudioSettings {
    static func fake(
        input: RawDeviceSettings = .fake(),
        output: RawDeviceSettings = .fake(),
        bufferSize: UInt32? = nil,
        sampleRate: Float64? = nil
    ) -> RawAudioSettings {
        RawAudioSettings(input: input, output: output, bufferSize: bufferSize, sampleRate: sampleRate)
    }
}
