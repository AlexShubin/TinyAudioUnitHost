//
//  EngineConfigurationObserver.swift
//  ChannelStripKit
//
//  Created by Alex Shubin on 24.11.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AVFoundation
import Common

/// The engine stops itself when its device's configuration changes under it, e.g. while an interface settles after power-on.
@MainActor
final class EngineConfigurationObserver {
    private let observation: Cancellation

    init(channelStrip: ChannelStripType, notificationCenter: NotificationCenterType) {
        observation = notificationCenter.observe(.AVAudioEngineConfigurationChange) {
            await channelStrip.reconnect()
        }
    }
}
