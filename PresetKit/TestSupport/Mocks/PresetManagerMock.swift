//
//  PresetManagerMock.swift
//  PresetKitTestSupport
//
//  Created by Alex Shubin on 08.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioUnitsKit
import PresetKit

public actor PresetManagerMock: PresetManagerType {
    public enum Calls: Equatable, Sendable {
        case load
        case setCurrent(AudioUnitComponent)
        case save
        case persistSession
    }

    public private(set) var calls: [Calls] = []
    public var loadResult: LoadedAudioUnit?
    public var setCurrentResult: LoadedAudioUnit?
    public var isModifiedOnLoad: Bool

    public nonisolated let isModifiedStream: AsyncStream<Bool>
    private let continuation: AsyncStream<Bool>.Continuation

    public init(
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

    public func load() -> LoadedAudioUnit? {
        calls.append(.load)
        if loadResult != nil {
            continuation.yield(isModifiedOnLoad)
        }
        return loadResult
    }

    public func setCurrent(_ component: AudioUnitComponent) -> LoadedAudioUnit? {
        calls.append(.setCurrent(component))
        if setCurrentResult != nil {
            continuation.yield(true)
        }
        return setCurrentResult
    }

    public func save() {
        calls.append(.save)
        continuation.yield(false)
    }

    public func persistSession() {
        calls.append(.persistSession)
    }

    public func setLoadResult(_ value: LoadedAudioUnit?) {
        loadResult = value
    }

    public func setSetCurrentResult(_ value: LoadedAudioUnit?) {
        setCurrentResult = value
    }

    public func emitIsModified(_ value: Bool) {
        continuation.yield(value)
    }
}
