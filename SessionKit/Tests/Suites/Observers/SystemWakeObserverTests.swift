//
//  SystemWakeObserverTests.swift
//  SessionKitTests
//
//  Created by Alex Shubin on 14.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AppKit
import CommonTestSupport
import Testing
@testable import SessionKit

@MainActor
@Suite
struct SystemWakeObserverTests {
    var channelStripSpy: ChannelStripSpy!
    var workspaceNotificationCenterSpy: NotificationCenterSpy!
    var sut: SystemWakeObserverType!

    init() {
        channelStripSpy = ChannelStripSpy()
        workspaceNotificationCenterSpy = NotificationCenterSpy()
    }

    mutating func createSut() {
        sut = SystemWakeObserver(
            channelStrip: channelStripSpy,
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
    mutating func didWake_reconnectsChannelStrip() async {
        createSut()
        sut.start()

        await workspaceNotificationCenterSpy.handlers[NSWorkspace.didWakeNotification]?()

        #expect(channelStripSpy.calls == [.reconnect])
    }
}
