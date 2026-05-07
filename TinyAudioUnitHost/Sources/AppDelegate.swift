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
    var sessionPersister: SessionPersisterType?

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let sessionPersister else { return .terminateNow }
        Task { @MainActor in
            await sessionPersister.persistSession()
            NSApp.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }
}
