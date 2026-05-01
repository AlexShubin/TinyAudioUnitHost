//
//  TargetAudioDevice.swift
//  AudioSettings
//
//  Created by Alex Shubin on 27.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import Common

public struct TargetAudioDevice: Sendable, Equatable {
    public let device: AudioDevice
    public let inputSource: AudioDevice?
    public let outputSource: AudioDevice?
    public let inputOffset: Int
    public let outputOffset: Int

    public init(
        device: AudioDevice,
        inputSource: AudioDevice?,
        outputSource: AudioDevice?,
        inputOffset: Int,
        outputOffset: Int
    ) {
        self.device = device
        self.inputSource = inputSource
        self.outputSource = outputSource
        self.inputOffset = inputOffset
        self.outputOffset = outputOffset
    }
}
