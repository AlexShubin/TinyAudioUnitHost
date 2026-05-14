//
//  SetupRefresherTests.swift
//  AudioSettingsKitTests
//
//  Created by Alex Shubin on 14.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AppKit
import AudioSettingsKitTestSupport
import CommonTestSupport
import Testing
@testable import AudioSettingsKit

@Suite
struct SetupRefresherTests {
    var setupCheckerMock: SetupCheckerMock!
    var notificationCenterMock: NotificationCenterMock!
    var sut: SetupRefresher!

    init() {
        setupCheckerMock = SetupCheckerMock()
        notificationCenterMock = NotificationCenterMock()
    }

    mutating func createSut() {
        sut = SetupRefresher(setupChecker: setupCheckerMock, notificationCenter: notificationCenterMock)
    }

    @Test
    mutating func startListening_subscribesToDidBecomeActive() {
        createSut()

        sut.startListening()

        #expect(notificationCenterMock.calls == [.stream(NSApplication.didBecomeActiveNotification)])
    }

    @Test
    mutating func startListening_emittedActivation_refreshesSetup() async {
        createSut()

        let task = sut.startListening()
        notificationCenterMock.emit(NSApplication.didBecomeActiveNotification)
        notificationCenterMock.finish(NSApplication.didBecomeActiveNotification)
        try? await task.value

        #expect(await setupCheckerMock.calls == [.refresh])
    }
}
