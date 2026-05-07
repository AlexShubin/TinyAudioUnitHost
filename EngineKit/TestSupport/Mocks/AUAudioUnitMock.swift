//
//  AUAudioUnitMock.swift
//  EngineKitTestSupport
//
//  Created by Alex Shubin on 06.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AppKit
import EngineKit
import Foundation

public final class AUAudioUnitMock: AUAudioUnitType, @unchecked Sendable {
    public var fullState: Data?
    public let modifications: AsyncStream<Void>
    private let continuation: AsyncStream<Void>.Continuation

    public init(fullState: Data? = nil) {
        self.fullState = fullState
        let (stream, continuation) = AsyncStream<Void>.makeStream()
        self.modifications = stream
        self.continuation = continuation
    }

    deinit {
        continuation.finish()
    }

    @MainActor
    public func requestViewController() async -> NSViewController? { nil }

    public func triggerOnChange() {
        continuation.yield()
    }
}
