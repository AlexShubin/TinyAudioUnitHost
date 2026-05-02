//
//  TargetDevice.swift
//  AudioSettingsKit
//
//  Created by Alex Shubin on 27.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

public struct TargetDevice: Sendable, Equatable {
    public let settings: AudioSettings
    public let device: AudioDevice

    public init(settings: AudioSettings, device: AudioDevice) {
        self.settings = settings
        self.device = device
    }
}
