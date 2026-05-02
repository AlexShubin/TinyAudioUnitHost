//
//  TargetSettingsProviderMock.swift
//  AudioSettingsKitTestSupport
//
//  Created by Alex Shubin on 30.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioSettingsKit

public actor TargetSettingsProviderMock: TargetSettingsProviderType {
    public enum Calls: Equatable {
        case resolveTarget
    }

    public private(set) var calls: [Calls] = []
    public var resolveTargetResult: TargetSettings?

    public init(resolveTargetResult: TargetSettings? = nil) {
        self.resolveTargetResult = resolveTargetResult
    }

    public func resolveTarget() -> TargetSettings? {
        calls.append(.resolveTarget)
        return resolveTargetResult
    }

    public func setResolveTargetResult(_ value: TargetSettings?) {
        resolveTargetResult = value
    }
}
