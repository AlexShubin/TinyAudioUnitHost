//
//  EngineReloaderTests.swift
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

@Suite
struct EngineReloaderTests {
    var engineMock: EngineMock!
    var workspaceNotificationCenterMock: NotificationCenterMock!
    var sut: EngineReloader!

    init() {
        engineMock = EngineMock()
        workspaceNotificationCenterMock = NotificationCenterMock()
    }

    mutating func createSut() {
        sut = EngineReloader(
            engine: engineMock,
            workspaceNotificationCenter: workspaceNotificationCenterMock
        )
    }

    @Test
    mutating func start_subscribesOnWorkspaceCenter() {
        createSut()

        sut.start()

        #expect(workspaceNotificationCenterMock.calls == [.stream(NSWorkspace.didWakeNotification)])
    }

    @Test
    mutating func start_workspaceDidWakeEmitted_callsEngineReload() async {
        createSut()

        let task = sut.start()
        workspaceNotificationCenterMock.emit(NSWorkspace.didWakeNotification)
        workspaceNotificationCenterMock.finish(NSWorkspace.didWakeNotification)
        try? await task.value

        #expect(engineMock.calls == [.reload])
    }
}
