//
//  SessionManagerDelegateMock.swift
//  TinyAudioUnitHostTests
//
//  Created by Alex Shubin on 12.08.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import Foundation
@testable import TinyAudioUnitHost

@MainActor
final class SessionManagerDelegateMock: SessionManagerDelegate {
    enum Calls: Equatable {
        case didSavePreset
        case didRestorePreset
    }

    private(set) var calls: [Calls] = []

    func sessionManagerDidSavePreset() {
        calls.append(.didSavePreset)
    }

    func sessionManagerDidRestorePreset() {
        calls.append(.didRestorePreset)
    }
}
