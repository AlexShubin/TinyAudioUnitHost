//
//  SessionManagerMock.swift
//  TinyAudioUnitHostTests
//
//  Created by Alex Shubin on 09.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioUnitsKit
@testable import TinyAudioUnitHost

actor SessionManagerMock: SessionManagerType {
    enum Calls: Equatable, Sendable {
        case activate(ActivationSource)
        case save
        case persistSession
    }

    private(set) var calls: [Calls] = []
    var activateResult: LoadedAudioUnit?
    var isModifiedOnLoad: Bool

    nonisolated let isModifiedStream: AsyncStream<Bool>
    private let continuation: AsyncStream<Bool>.Continuation

    init(activateResult: LoadedAudioUnit? = nil, isModifiedOnLoad: Bool = false) {
        self.activateResult = activateResult
        self.isModifiedOnLoad = isModifiedOnLoad
        let (stream, continuation) = AsyncStream<Bool>.makeStream()
        self.isModifiedStream = stream
        self.continuation = continuation
    }

    deinit {
        continuation.finish()
    }

    func activate(_ source: ActivationSource) -> LoadedAudioUnit? {
        calls.append(.activate(source))
        switch source {
        case .stored:
            if activateResult != nil { continuation.yield(isModifiedOnLoad) }
        case .picked:
            if activateResult != nil { continuation.yield(true) }
        case .savedDefault:
            continuation.yield(false)
        }
        return activateResult
    }

    func save() {
        calls.append(.save)
        continuation.yield(false)
    }

    func persistSession() {
        calls.append(.persistSession)
    }

    func emitIsModified(_ value: Bool) {
        continuation.yield(value)
    }

    func setActivateResult(_ value: LoadedAudioUnit?) {
        activateResult = value
    }
}
