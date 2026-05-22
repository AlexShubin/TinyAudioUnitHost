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
        case startListening
    }

    public private(set) var calls: [Calls] = []

    public init() {}

    @discardableResult
    public func startListening() -> Task<Void, Error> {
        calls.append(.startListening)
        return Task {}
    }
}
