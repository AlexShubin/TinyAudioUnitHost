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
        // Must stay first — see MidiReloader.start.
        dependencies.engine.midiReloader.start()
        dependencies.engine.engineReloader.start()
        dependencies.audioSettings.setupRefresher.start()
        dependencies.purchases.purchasesService.start()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
