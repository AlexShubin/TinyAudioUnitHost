//
//  AggregateDeviceManagerMock.swift
//  EngineKitTestSupport
//
//  Created by Alex Shubin on 30.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import Common
import EngineKit

public actor AggregateDeviceManagerMock: AggregateDeviceManagerType {
    public enum Calls: Equatable {
        case resolveTarget
    }

    public private(set) var calls: [Calls] = []
    public var resolveTargetResult: TargetAudioDevice?

    public init(resolveTargetResult: TargetAudioDevice? = nil) {
        self.resolveTargetResult = resolveTargetResult
    }

    public func resolveTarget() -> TargetAudioDevice? {
        calls.append(.resolveTarget)
        return resolveTargetResult
    }

    public func setResolveTargetResult(_ value: TargetAudioDevice?) {
        resolveTargetResult = value
    }
}
