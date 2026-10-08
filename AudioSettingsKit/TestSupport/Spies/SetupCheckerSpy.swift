//
//  SetupCheckerSpy.swift
//  AudioSettingsKitTestSupport
//
//  Created by Alex Shubin on 22.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioSettingsKit

public final class SetupCheckerSpy: SetupCheckerType, @unchecked Sendable {
    public enum Calls: Equatable, Sendable {
        case check
    }

    public private(set) var calls: [Calls] = []

    public init() {}

    public var checkResult: Set<SetupRequirement> = []
    public func check() async -> Set<SetupRequirement> {
        calls.append(.check)
        return checkResult
    }
}
