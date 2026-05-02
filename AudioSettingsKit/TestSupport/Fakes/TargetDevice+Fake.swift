//
//  TargetDevice+Fake.swift
//  AudioSettingsKitTestSupport
//
//  Created by Alex Shubin on 30.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioSettingsKit

public extension TargetDevice {
    static func fake(
        settings: AudioSettings = .empty,
        device: AudioDevice = .fake()
    ) -> TargetDevice {
        TargetDevice(settings: settings, device: device)
    }
}
