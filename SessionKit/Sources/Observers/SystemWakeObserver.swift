//
//  SystemWakeObserver.swift
//  SessionKit
//
//  Created by Alex Shubin on 14.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AppKit
import Common

@MainActor
final class SystemWakeObserver {
    private let observation: Cancellation

    init(channelStrip: ChannelStripType, workspaceNotificationCenter: NotificationCenterType) {
        observation = workspaceNotificationCenter.observe(NSWorkspace.didWakeNotification) {
            await channelStrip.reconnect()
        }
    }
}
