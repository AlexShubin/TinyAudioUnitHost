//
//  SessionCommandRouterMock.swift
//  TinyAudioUnitHostTests
//
//  Created by Alex Shubin on 12.08.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import Foundation
@testable import TinyAudioUnitHost

@MainActor
final class SessionCommandRouterMock: SessionCommandRouterType {
    enum Calls: Equatable {
        case setSaveAsCommand
        case executeSaveAsCommand
    }

    private(set) var calls: [Calls] = []

    private(set) var saveAsCommand: (() -> Void)?
    func setSaveAsCommand(_ command: @escaping () -> Void) {
        saveAsCommand = command
        calls.append(.setSaveAsCommand)
    }

    func executeSaveAsCommand() {
        calls.append(.executeSaveAsCommand)
    }
}
