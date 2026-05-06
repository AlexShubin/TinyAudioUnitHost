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
    public private(set) var observedBlock: (@Sendable () -> Void)?

    public init(fullState: Data? = nil) {
        self.fullState = fullState
    }

    @MainActor
    public func requestViewController() async -> NSViewController? { nil }

    public func onChange(_ block: @escaping @Sendable () -> Void) {
        observedBlock = block
    }

    public func triggerOnChange() {
        observedBlock?()
    }
}
