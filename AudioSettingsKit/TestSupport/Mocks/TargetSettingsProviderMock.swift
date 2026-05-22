//
//  TargetSettingsProviderMock.swift
//  AudioSettingsKitTestSupport
//
//  Created by Alex Shubin on 30.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioSettingsKit

public final class TargetSettingsProviderMock: TargetSettingsProviderType, @unchecked Sendable {
    public enum Calls: Equatable, Sendable {
        case resolveTarget
    }

    public private(set) var calls: [Calls] = []
    public var resolveTargetResult: TargetSettings?

    public init(resolveTargetResult: TargetSettings? = nil) {
        self.resolveTargetResult = resolveTargetResult
    }

    public func resolveTarget() async -> TargetSettings? {
        calls.append(.resolveTarget)
        return resolveTargetResult
    }
}
