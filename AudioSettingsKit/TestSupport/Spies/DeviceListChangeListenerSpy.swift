//
//  DeviceListChangeListenerSpy.swift
//  AudioSettingsKitTestSupport
//
//  Created by Alex Shubin on 22.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioSettingsKit
import Common

public final class DeviceListChangeListenerSpy: DeviceListChangeListenerType, @unchecked Sendable {
    public enum Calls: Equatable, Sendable {
        case observeChanges
    }

    public private(set) var calls: [Calls] = []

    public init() {}

    public private(set) var changesHandler: (@Sendable () async -> Void)?
    public func observeChanges(_ handler: @escaping @Sendable () async -> Void) -> Cancellation {
        changesHandler = handler
        calls.append(.observeChanges)
        return Cancellation {}
    }
}
