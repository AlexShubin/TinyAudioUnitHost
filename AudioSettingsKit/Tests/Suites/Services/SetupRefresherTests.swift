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
    var deviceListListenerMock: DeviceListChangeListenerMock!
    var sut: SetupRefresher!

    init() {
        setupCheckerMock = SetupCheckerMock()
        notificationCenterMock = NotificationCenterMock()
        deviceListListenerMock = DeviceListChangeListenerMock()
    }

    mutating func createSut() {
        sut = SetupRefresher(
            setupChecker: setupCheckerMock,
            notificationCenter: notificationCenterMock,
            deviceListListener: deviceListListenerMock
        )
    }

    @Test
    mutating func startListening_subscribesToBothSources() {
        createSut()

        _ = sut.startListening()

        #expect(notificationCenterMock.calls == [.stream(NSApplication.didBecomeActiveNotification)])
        #expect(deviceListListenerMock.calls == [.stream])
    }

    @Test
    mutating func startListening_emittedActivation_refreshesSetup() async {
        createSut()

        let tasks = sut.startListening()
        notificationCenterMock.emit(NSApplication.didBecomeActiveNotification)
        notificationCenterMock.finish(NSApplication.didBecomeActiveNotification)
        deviceListListenerMock.finish()
        for task in tasks { try? await task.value }

        #expect(await setupCheckerMock.calls == [.refresh])
    }

    @Test
    mutating func startListening_emittedDeviceListChange_refreshesSetup() async {
        createSut()

        let tasks = sut.startListening()
        deviceListListenerMock.emit()
        deviceListListenerMock.finish()
        notificationCenterMock.finish(NSApplication.didBecomeActiveNotification)
        for task in tasks { try? await task.value }

        #expect(await setupCheckerMock.calls == [.refresh])
    }
}
