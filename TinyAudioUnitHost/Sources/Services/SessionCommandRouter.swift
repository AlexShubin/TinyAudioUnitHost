//
//  SessionCommandRouter.swift
//  TinyAudioUnitHost
//
//  Created by Alex Shubin on 12.08.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import Foundation

@MainActor
final class SessionCommandRouter {
    private var savedCommand: (() -> Void)?
    private var restoredCommand: (() -> Void)?
    private var saveAsCommand: (() -> Void)?

    nonisolated init() {}

    func setSavedCommand(_ command: @escaping () -> Void) {
        savedCommand = command
    }

    func executeSavedCommand() {
        savedCommand?()
    }

    func setRestoredCommand(_ command: @escaping () -> Void) {
        restoredCommand = command
    }

    func executeRestoredCommand() {
        restoredCommand?()
    }

    func setSaveAsCommand(_ command: @escaping () -> Void) {
        saveAsCommand = command
    }

    func executeSaveAsCommand() {
        saveAsCommand?()
    }
}
