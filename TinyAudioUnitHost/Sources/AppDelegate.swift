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
    func applicationWillFinishLaunching(_ notification: Notification) {
        guard !isRunningTests else { return }
        let dependencies = Dependencies.live
        dependencies.engine.systemWakeObserver.start()
        dependencies.audioSettingsObserver.start()
        Task { await dependencies.audioSettings.audioSettingsModel.load() }
        Task { await dependencies.purchases.purchasesModel.load() }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
