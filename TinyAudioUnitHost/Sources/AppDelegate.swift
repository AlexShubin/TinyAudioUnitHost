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
    var sessionManager: SessionManagerType?

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    /// On quit (X click via `applicationShouldTerminateAfterLastWindowClosed`,
    /// or Cmd-Q), tell the session manager to persist the session — it writes
    /// `raw_session.json` if the working state is dirty, or deletes it if not.
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let sessionManager else { return .terminateNow }
        Task { @MainActor in
            await sessionManager.persistSession()
            NSApp.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }
}
