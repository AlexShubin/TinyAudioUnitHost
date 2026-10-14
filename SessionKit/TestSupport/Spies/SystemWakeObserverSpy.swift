//
//  SystemWakeObserverSpy.swift
//  SessionKitTestSupport
//
//  Created by Alex Shubin on 08.10.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import SessionKit

@MainActor
public final class SystemWakeObserverSpy: SystemWakeObserverType {
    public enum Calls: Equatable {
        case start
    }

    public private(set) var calls: [Calls] = []

    public init() {}

    public func start() {
        calls.append(.start)
    }
}
