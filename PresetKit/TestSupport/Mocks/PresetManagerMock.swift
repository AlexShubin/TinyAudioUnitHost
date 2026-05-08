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
        case setCurrent(LoadedAudioUnit?, isModified: Bool)
        case save
        case persistSession
    }

    public private(set) var calls: [Calls] = []
    public var activePreset: ActivePreset?

    public nonisolated let isModifiedStream: AsyncStream<Bool>
    private let continuation: AsyncStream<Bool>.Continuation

    public init(activePreset: ActivePreset? = nil) {
        self.activePreset = activePreset
        let (stream, continuation) = AsyncStream<Bool>.makeStream()
        self.isModifiedStream = stream
        self.continuation = continuation
    }

    deinit {
        continuation.finish()
    }

    public func load() -> ActivePreset? {
        calls.append(.load)
        return activePreset
    }

    public func setCurrent(_ loaded: LoadedAudioUnit?, isModified: Bool) {
        calls.append(.setCurrent(loaded, isModified: isModified))
        continuation.yield(isModified)
    }

    public func save() {
        calls.append(.save)
        continuation.yield(false)
    }

    public func persistSession() {
        calls.append(.persistSession)
    }

    public func setActivePreset(_ value: ActivePreset?) {
        activePreset = value
    }

    public func emitIsModified(_ value: Bool) {
        continuation.yield(value)
    }
}
