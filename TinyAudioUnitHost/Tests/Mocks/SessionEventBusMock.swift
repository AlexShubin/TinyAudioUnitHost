//
//  SessionEventBusMock.swift
//  TinyAudioUnitHostTests
//
//  Created by Alex Shubin on 21.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import Foundation
@testable import TinyAudioUnitHost

@MainActor
final class SessionEventBusMock: SessionEventBusType {
    enum Calls: Equatable, Sendable {
        case post(SessionEvent)
    }

    private(set) var calls: [Calls] = []

    private var continuation: AsyncStream<SessionEvent>.Continuation?

    init() {}

    func post(_ event: SessionEvent) {
        continuation?.yield(event)
        calls.append(.post(event))
    }

    func makeEventStream() -> AsyncStream<SessionEvent> {
        let (stream, continuation) = AsyncStream<SessionEvent>.makeStream()
        self.continuation = continuation
        return stream
    }
}
