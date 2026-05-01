//
//  TargetAudioDevice+Fake.swift
//  AudioSettingsTestSupport
//
//  Created by Alex Shubin on 30.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioSettings

public extension TargetAudioDevice {
    static func fake(
        device: AudioDevice = .fake(),
        inputSource: AudioDevice? = .fake(),
        outputSource: AudioDevice? = .fake(),
        inputOffset: Int = 0,
        outputOffset: Int = 0
    ) -> TargetAudioDevice {
        TargetAudioDevice(
            device: device,
            inputSource: inputSource,
            outputSource: outputSource,
            inputOffset: inputOffset,
            outputOffset: outputOffset
        )
    }
}
