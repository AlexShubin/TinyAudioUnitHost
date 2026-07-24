//
//  EngineReloaderMock.swift
//  EngineKitTestSupport
//
//  Created by Alex Shubin on 22.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import EngineKit

public final class EngineReloaderMock: EngineReloaderType, @unchecked Sendable {
    public enum Calls: Equatable, Sendable {
        case start
    }

    public private(set) var calls: [Calls] = []

    public init() {}

    @discardableResult
    public func start() -> Task<Void, Error> {
        calls.append(.start)
        return Task {}
    }
}
