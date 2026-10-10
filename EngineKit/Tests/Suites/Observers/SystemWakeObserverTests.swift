//
//  SystemWakeObserverTests.swift
//  EngineKitTests
//
//  Created by Alex Shubin on 14.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AppKit
import CommonTestSupport
import EngineKitTestSupport
import Testing
@testable import EngineKit

@MainActor
@Suite
struct SystemWakeObserverTests {
    var engineSpy: EngineSpy!
    var workspaceNotificationCenterSpy: NotificationCenterSpy!
    var sut: SystemWakeObserverType!

    init() {
        engineSpy = EngineSpy()
        workspaceNotificationCenterSpy = NotificationCenterSpy()
    }

    mutating func createSut() {
        sut = SystemWakeObserver(
            engine: engineSpy,
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
    mutating func didWake_reloadsEngine() async {
        createSut()
        sut.start()

        await workspaceNotificationCenterSpy.handlers[NSWorkspace.didWakeNotification]?()

        #expect(engineSpy.calls == [.reload])
    }
}
