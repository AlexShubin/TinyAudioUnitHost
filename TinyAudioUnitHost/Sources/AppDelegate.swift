//
//  AppDelegate.swift
//  TinyAudioUnitHost
//
//  Created by Alex Shubin on 07.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    var quitCoordinator: QuitCoordinatorType?

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let quitCoordinator else { return .terminateNow }
        Task { @MainActor in
            let proceed = await quitCoordinator.requestQuit()
            NSApp.reply(toApplicationShouldTerminate: proceed)
        }
        return .terminateLater
    }
}
