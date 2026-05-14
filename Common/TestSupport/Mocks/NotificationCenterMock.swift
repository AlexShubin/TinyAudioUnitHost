//
//  NotificationCenterMock.swift
//  CommonTestSupport
//
//  Created by Alex Shubin on 13.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import Common
import Foundation

public final class NotificationCenterMock: NotificationCenterType, @unchecked Sendable {
    public enum Calls: Equatable, Sendable {
        case stream(Notification.Name)
    }

    public private(set) var calls: [Calls] = []
    private var continuations: [Notification.Name: AsyncStream<Void>.Continuation] = [:]

    public init() {}

    public func stream(for name: Notification.Name) -> AsyncStream<Void> {
        calls.append(.stream(name))
        let (stream, continuation) = AsyncStream<Void>.makeStream()
        continuations[name] = continuation
        return stream
    }

    public func emit(_ name: Notification.Name) {
        continuations[name]?.yield()
    }

    public func finish(_ name: Notification.Name) {
        continuations[name]?.finish()
    }
}
