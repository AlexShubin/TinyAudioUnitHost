//
//  AudioSettings+Fake.swift
//  StorageKitTestSupport
//
//  Created by Alex Shubin on 30.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import StorageKit

public extension AudioSettings {
    static func fake(
        input: DeviceSettings = .fake(),
        output: DeviceSettings = .fake(),
        bufferSize: UInt32? = nil,
        sampleRate: Float64? = nil
    ) -> AudioSettings {
        AudioSettings(input: input, output: output, bufferSize: bufferSize, sampleRate: sampleRate)
    }
}
