//
//  MidiReloaderMock.swift
//  EngineKitTestSupport
//
//  Created by Alex Shubin on 24.07.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import EngineKit

public final class MidiReloaderMock: MidiReloaderType, @unchecked Sendable {
    public enum Calls: Equatable {
        case start
    }

    public private(set) var calls: [Calls] = []

    public nonisolated init() {}

    @discardableResult
    public func start() -> Task<Void, Error> {
        calls.append(.start)
        return Task {}
    }
}
