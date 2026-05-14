//
//  NotificationCenterType.swift
//  EngineKit
//
//  Created by Alex Shubin on 13.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import Foundation
import Synchronization

protocol NotificationCenterType: Sendable {
    func stream(for name: Notification.Name) -> AsyncStream<Void>
}

extension NotificationCenter: NotificationCenterType {
    func stream(for name: Notification.Name) -> AsyncStream<Void> {
        AsyncStream { continuation in
            let observer = Mutex(
                self.addObserver(forName: name, object: nil, queue: nil) { _ in
                    continuation.yield()
                }
            )
            continuation.onTermination = { [self] _ in
                observer.withLock {
                    self.removeObserver($0)
                }
            }
        }
    }
}
