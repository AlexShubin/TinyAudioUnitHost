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
        case load
        case setCurrent(AudioUnitComponent)
        case save
        case persistSession
    }

    private(set) var calls: [Calls] = []
    var loadResult: LoadedAudioUnit?
    var setCurrentResult: LoadedAudioUnit?
    var isModifiedOnLoad: Bool

    nonisolated let isModifiedStream: AsyncStream<Bool>
    private let continuation: AsyncStream<Bool>.Continuation

    init(
        loadResult: LoadedAudioUnit? = nil,
        setCurrentResult: LoadedAudioUnit? = nil,
        isModifiedOnLoad: Bool = false
    ) {
        self.loadResult = loadResult
        self.setCurrentResult = setCurrentResult
        self.isModifiedOnLoad = isModifiedOnLoad
        let (stream, continuation) = AsyncStream<Bool>.makeStream()
        self.isModifiedStream = stream
        self.continuation = continuation
    }

    deinit {
        continuation.finish()
    }

    func load() -> LoadedAudioUnit? {
        calls.append(.load)
        if loadResult != nil {
            continuation.yield(isModifiedOnLoad)
        }
        return loadResult
    }

    func setCurrent(_ component: AudioUnitComponent) -> LoadedAudioUnit? {
        calls.append(.setCurrent(component))
        if setCurrentResult != nil {
            continuation.yield(true)
        }
        return setCurrentResult
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
}
