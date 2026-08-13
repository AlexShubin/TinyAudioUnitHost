//
//  SessionCommandRouter.swift
//  TinyAudioUnitHost
//
//  Created by Alex Shubin on 12.08.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import Foundation

@MainActor
protocol SessionCommandRouterType: AnyObject, Sendable {
    func setSaveAsCommand(_ command: @escaping () -> Void)
    func executeSaveAsCommand()
}

@MainActor
final class SessionCommandRouter: SessionCommandRouterType {
    private var saveAsCommand: (() -> Void)?

    nonisolated init() {}

    func setSaveAsCommand(_ command: @escaping () -> Void) {
        saveAsCommand = command
    }

    func executeSaveAsCommand() {
        saveAsCommand?()
    }
}
