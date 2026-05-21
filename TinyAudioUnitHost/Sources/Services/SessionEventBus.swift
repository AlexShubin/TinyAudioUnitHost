//
//  SessionEventBus.swift
//  TinyAudioUnitHost
//
//  Created by Alex Shubin on 21.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import Foundation

@MainActor
protocol SessionEventBusType: AnyObject, Sendable {
    func post(_ event: SessionEvent)
    func makeEventStream() -> AsyncStream<SessionEvent>
}

enum SessionEvent: Sendable, Equatable {
    case saved
    case restored
    case saveAsRequested
}

@MainActor
final class SessionEventBus: SessionEventBusType {
    private var continuations: [UUID: AsyncStream<SessionEvent>.Continuation] = [:]

    nonisolated init() {}

    func post(_ event: SessionEvent) {
        for continuation in continuations.values {
            continuation.yield(event)
        }
    }

    func makeEventStream() -> AsyncStream<SessionEvent> {
        AsyncStream { continuation in
            let id = UUID()
            self.continuations[id] = continuation
            continuation.onTermination = { [weak self] _ in
                Task { @MainActor in
                    self?.continuations.removeValue(forKey: id)
                }
            }
        }
    }
}
