//
//  SystemWakeObserverTests.swift
//  SessionKitTests
//
//  Created by Alex Shubin on 14.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AppKit
import CommonTestSupport
import SessionKitTestSupport
import Testing
@testable import SessionKit

@MainActor
@Suite
struct SystemWakeObserverTests {
    var pluginChainSpy: PluginChainSpy!
    var workspaceNotificationCenterSpy: NotificationCenterSpy!
    var sut: SystemWakeObserverType!

    init() {
        pluginChainSpy = PluginChainSpy()
        workspaceNotificationCenterSpy = NotificationCenterSpy()
    }

    mutating func createSut() {
        sut = SystemWakeObserver(
            pluginChain: pluginChainSpy,
            workspaceNotificationCenter: workspaceNotificationCenterSpy
        )
    }

    @Test
    mutating func start_observesWorkspaceDidWake() {
        createSut()

        sut.start()

        #expect(workspaceNotificationCenterSpy.calls == [.observe(NSWorkspace.didWakeNotification)])
    }

    @Test
    mutating func start_calledTwice_observesOnce() {
        createSut()

        sut.start()
        sut.start()

        #expect(workspaceNotificationCenterSpy.calls == [.observe(NSWorkspace.didWakeNotification)])
    }

    @Test
    mutating func didWake_reconnectsPluginChain() async {
        createSut()
        sut.start()

        await workspaceNotificationCenterSpy.handlers[NSWorkspace.didWakeNotification]?()

        #expect(pluginChainSpy.calls == [.reconnect])
    }
}
