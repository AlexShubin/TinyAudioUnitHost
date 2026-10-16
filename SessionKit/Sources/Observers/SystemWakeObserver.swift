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
public protocol SystemWakeObserverType: Sendable {
    func start()
}

@MainActor
final class SystemWakeObserver: SystemWakeObserverType {
    private let channelStrip: ChannelStripType
    private let workspaceNotificationCenter: NotificationCenterType
    private var observation: Cancellation?

    init(channelStrip: ChannelStripType, workspaceNotificationCenter: NotificationCenterType) {
        self.channelStrip = channelStrip
        self.workspaceNotificationCenter = workspaceNotificationCenter
    }

    func start() {
        guard observation == nil else { return }
        observation = workspaceNotificationCenter.observe(NSWorkspace.didWakeNotification) { [channelStrip] in
            await channelStrip.reconnect()
        }
    }
}
