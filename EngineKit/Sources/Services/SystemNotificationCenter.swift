//
//  SystemNotificationCenter.swift
//  EngineKit
//
//  Created by Alex Shubin on 14.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AppKit
import Foundation

/// Routes notification subscriptions to the appropriate underlying NotificationCenter.
/// NSWorkspace notifications live on `NSWorkspace.shared.notificationCenter`;
/// everything else goes through `NotificationCenter.default`.
struct SystemNotificationCenter: NotificationCenterType {
    func stream(for name: Notification.Name) -> AsyncStream<Void> {
        center(for: name).stream(for: name)
    }

    private func center(for name: Notification.Name) -> NotificationCenter {
        switch name {
        case NSWorkspace.didWakeNotification:
            return NSWorkspace.shared.notificationCenter
        default:
            return NotificationCenter.default
        }
    }
}
