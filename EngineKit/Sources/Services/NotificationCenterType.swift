//
//  NotificationCenterType.swift
//  EngineKit
//
//  Created by Alex Shubin on 13.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import Foundation

protocol NotificationCenterType: Sendable {
    func stream(for name: Notification.Name) -> AsyncStream<Void>
}

// The observer token is created in the stream's setup, captured once by the
// onTermination closure, and read only there — no concurrent access, so the
// unchecked Sendable conformance is safe.
private final class ObserverToken: @unchecked Sendable {
    let token: NSObjectProtocol
    init(_ token: NSObjectProtocol) { self.token = token }
}

extension NotificationCenter: NotificationCenterType {
    func stream(for name: Notification.Name) -> AsyncStream<Void> {
        AsyncStream { continuation in
            let observer = ObserverToken(
                self.addObserver(forName: name, object: nil, queue: nil) { _ in
                    continuation.yield()
                }
            )
            continuation.onTermination = { [self] _ in
                self.removeObserver(observer.token)
            }
        }
    }
}
