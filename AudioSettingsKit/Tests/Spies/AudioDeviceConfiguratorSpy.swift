//
//  AudioDeviceConfiguratorSpy.swift
//  AudioSettingsKitTests
//
//  Created by Alex Shubin on 09.10.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

@testable import AudioSettingsKit

final class AudioDeviceConfiguratorSpy: AudioDeviceConfiguratorType, @unchecked Sendable {
    enum Calls: Equatable {
        case apply(AudioSettings, AudioDevice)
    }

    private(set) var calls: [Calls] = []

    func apply(_ settings: AudioSettings, to device: AudioDevice) {
        calls.append(.apply(settings, device))
    }
}
