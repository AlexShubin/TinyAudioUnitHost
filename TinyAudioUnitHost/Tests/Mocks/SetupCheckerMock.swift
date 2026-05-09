//
//  SetupCheckerMock.swift
//  TinyAudioUnitHostTests
//
//  Created by Alex Shubin on 09.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

@testable import TinyAudioUnitHost

actor SetupCheckerMock: SetupCheckerType {
    enum Calls: Equatable, Sendable {
        case refresh
    }

    private(set) var calls: [Calls] = []
    var unmet: Set<SetupRequirement>

    nonisolated let unmetStream: AsyncStream<Set<SetupRequirement>>
    private let continuation: AsyncStream<Set<SetupRequirement>>.Continuation

    init(unmet: Set<SetupRequirement> = []) {
        self.unmet = unmet
        let (stream, continuation) = AsyncStream<Set<SetupRequirement>>.makeStream()
        self.unmetStream = stream
        self.continuation = continuation
    }

    deinit {
        continuation.finish()
    }

    func refresh() {
        calls.append(.refresh)
        continuation.yield(unmet)
    }

    func emit(_ value: Set<SetupRequirement>) {
        unmet = value
        continuation.yield(value)
    }
}
