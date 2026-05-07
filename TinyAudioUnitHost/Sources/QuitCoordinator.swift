//
//  QuitCoordinator.swift
//  TinyAudioUnitHost
//
//  Created by Alex Shubin on 07.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import Foundation

protocol QuitCoordinatorType: Sendable {
    var requests: AsyncStream<Void> { get }
    func requestQuit() async -> Bool
    func resolve(proceed: Bool) async
}

actor QuitCoordinator: QuitCoordinatorType {
    nonisolated let requests: AsyncStream<Void>
    nonisolated private let continuation: AsyncStream<Void>.Continuation
    private var pendingDecision: CheckedContinuation<Bool, Never>?

    init() {
        let (stream, continuation) = AsyncStream<Void>.makeStream()
        self.requests = stream
        self.continuation = continuation
    }

    func requestQuit() async -> Bool {
        await withCheckedContinuation { decisionCont in
            pendingDecision = decisionCont
            continuation.yield()
        }
    }

    func resolve(proceed: Bool) {
        pendingDecision?.resume(returning: proceed)
        pendingDecision = nil
    }
}
