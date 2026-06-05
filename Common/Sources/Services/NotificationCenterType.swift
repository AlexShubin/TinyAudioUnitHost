//
//  NotificationCenterType.swift
//  Common
//
//  Created by Alex Shubin on 13.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import Foundation

public protocol NotificationCenterType: Sendable {
    func stream(for name: Notification.Name) -> AsyncStream<Void>
}

extension NotificationCenter: NotificationCenterType {
    public func stream(for name: Notification.Name) -> AsyncStream<Void> {
        AsyncStream { continuation in
            nonisolated(unsafe) let observer = self.addObserver(forName: name, object: nil, queue: nil) { _ in
                continuation.yield()
            }
            continuation.onTermination = { [self] _ in
                self.removeObserver(observer)
            }
        }
    }
}
