//
//  DeviceListChangeListenerMock.swift
//  AudioSettingsKitTestSupport
//
//  Created by Alex Shubin on 22.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioSettingsKit

public final class DeviceListChangeListenerMock: DeviceListChangeListenerType, @unchecked Sendable {
    public enum Calls: Equatable, Sendable {
        case stream
    }

    public private(set) var calls: [Calls] = []
    private var continuation: AsyncStream<Void>.Continuation?

    public init() {}

    public func stream() -> AsyncStream<Void> {
        calls.append(.stream)
        let (stream, continuation) = AsyncStream<Void>.makeStream()
        self.continuation = continuation
        return stream
    }

    public func emit() {
        continuation?.yield()
    }

    public func finish() {
        continuation?.finish()
    }
}
