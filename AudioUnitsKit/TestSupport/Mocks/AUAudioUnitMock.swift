//
//  AUAudioUnitMock.swift
//  AudioUnitsKitTestSupport
//
//  Created by Alex Shubin on 06.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AppKit
import AudioUnitsKit
import Foundation

public final class AUAudioUnitMock: AUAudioUnitType, @unchecked Sendable {
    public var fullState: Data?

    public init(fullState: Data? = nil) {
        self.fullState = fullState
    }

    @MainActor
    public func requestViewController() async -> NSViewController? { nil }
}
