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
        case setSavedCommand
        case executeSavedCommand
        case setRestoredCommand
        case executeRestoredCommand
        case setSaveAsCommand
        case executeSaveAsCommand
    }

    private(set) var calls: [Calls] = []

    private(set) var savedCommand: (() -> Void)?
    func setSavedCommand(_ command: @escaping () -> Void) {
        savedCommand = command
        calls.append(.setSavedCommand)
    }

    func executeSavedCommand() {
        calls.append(.executeSavedCommand)
    }

    private(set) var restoredCommand: (() -> Void)?
    func setRestoredCommand(_ command: @escaping () -> Void) {
        restoredCommand = command
        calls.append(.setRestoredCommand)
    }

    func executeRestoredCommand() {
        calls.append(.executeRestoredCommand)
    }

    private(set) var saveAsCommand: (() -> Void)?
    func setSaveAsCommand(_ command: @escaping () -> Void) {
        saveAsCommand = command
        calls.append(.setSaveAsCommand)
    }

    func executeSaveAsCommand() {
        calls.append(.executeSaveAsCommand)
    }
}
