//
//  NotificationCenterType.swift
//  Common
//
//  Created by Alex Shubin on 13.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import Foundation

public protocol NotificationCenterType: Sendable {
    func observe(_ name: Notification.Name, handler: @escaping @Sendable () async -> Void) -> Cancellation
}

extension NotificationCenter: NotificationCenterType {
    public func observe(_ name: Notification.Name, handler: @escaping @Sendable () async -> Void) -> Cancellation {
        nonisolated(unsafe) let observer = addObserver(forName: name, object: nil, queue: nil) { _ in
            Task { await handler() }
        }
        return Cancellation { [self] in removeObserver(observer) }
    }
}
