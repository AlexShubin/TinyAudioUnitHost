//
//  AggregateDeviceManagerMock.swift
//  AudioSettingsKitTestSupport
//
//  Created by Alex Shubin on 30.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioSettingsKit

public actor AggregateDeviceManagerMock: AggregateDeviceManagerType {
    public enum Calls: Equatable {
        case resolveTarget
    }

    public private(set) var calls: [Calls] = []
    public var resolveTargetResult: TargetDevice?

    public init(resolveTargetResult: TargetDevice? = nil) {
        self.resolveTargetResult = resolveTargetResult
    }

    public func resolveTarget() -> TargetDevice? {
        calls.append(.resolveTarget)
        return resolveTargetResult
    }

    public func setResolveTargetResult(_ value: TargetDevice?) {
        resolveTargetResult = value
    }
}
