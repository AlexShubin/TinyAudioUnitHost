//
//  NotificationCenterSpy.swift
//  CommonTestSupport
//
//  Created by Alex Shubin on 13.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import Common
import Foundation

public final class NotificationCenterSpy: NotificationCenterType, @unchecked Sendable {
    public enum Calls: Equatable, Sendable {
        case observe(Notification.Name)
    }

    public private(set) var calls: [Calls] = []

    public init() {}

    public private(set) var handlers: [Notification.Name: @Sendable () async -> Void] = [:]
    public func observe(_ name: Notification.Name, handler: @escaping @Sendable () async -> Void) -> Cancellation {
        handlers[name] = handler
        calls.append(.observe(name))
        return Cancellation {}
    }
}
