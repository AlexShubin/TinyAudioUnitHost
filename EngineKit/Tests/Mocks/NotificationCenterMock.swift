//
//  NotificationCenterMock.swift
//  EngineKitTests
//
//  Created by Alex Shubin on 13.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import Foundation
@testable import EngineKit

final class NotificationCenterMock: NotificationCenterType, @unchecked Sendable {
    enum Calls: Equatable, Sendable {
        case stream(Notification.Name)
    }

    private(set) var calls: [Calls] = []
    private var continuations: [Notification.Name: AsyncStream<Void>.Continuation] = [:]

    init() {}

    func stream(for name: Notification.Name) -> AsyncStream<Void> {
        calls.append(.stream(name))
        let (stream, continuation) = AsyncStream<Void>.makeStream()
        continuations[name] = continuation
        return stream
    }

    func emit(_ name: Notification.Name) {
        continuations[name]?.yield()
    }

    func finish(_ name: Notification.Name) {
        continuations[name]?.finish()
    }
}
