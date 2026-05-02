//
//  TargetSettings+Fake.swift
//  AudioSettingsKitTestSupport
//
//  Created by Alex Shubin on 30.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioSettingsKit

public extension TargetSettings {
    static func fake(
        settings: AudioSettings = .empty,
        device: AudioDevice = .fake()
    ) -> TargetSettings {
        TargetSettings(settings: settings, device: device)
    }
}
