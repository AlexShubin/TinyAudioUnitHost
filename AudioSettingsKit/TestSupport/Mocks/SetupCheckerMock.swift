//
//  SetupCheckerMock.swift
//  AudioSettingsKitTestSupport
//
//  Created by Alex Shubin on 09.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioSettingsKit

public actor SetupCheckerMock: SetupCheckerType {
    public enum Calls: Equatable, Sendable {
        case refresh
    }

    public private(set) var calls: [Calls] = []
    public var unmet: Set<SetupRequirement>

    public nonisolated let unmetStream: AsyncStream<Set<SetupRequirement>>
    private let continuation: AsyncStream<Set<SetupRequirement>>.Continuation

    public init(unmet: Set<SetupRequirement> = []) {
        self.unmet = unmet
        let (stream, continuation) = AsyncStream<Set<SetupRequirement>>.makeStream()
        self.unmetStream = stream
        self.continuation = continuation
    }

    deinit {
        continuation.finish()
    }

    public func refresh() {
        calls.append(.refresh)
        continuation.yield(unmet)
    }

    public func emit(_ value: Set<SetupRequirement>) {
        unmet = value
        continuation.yield(value)
    }
}
