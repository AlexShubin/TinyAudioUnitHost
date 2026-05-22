//
//  SetupRefresherTests.swift
//  AudioSettingsKitTests
//
//  Created by Alex Shubin on 14.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AppKit
import AudioSettingsKitTestSupport
import AVFoundation
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
    mutating func startListening_subscribesToBothTriggers() {
        createSut()

        _ = sut.startListening()

        #expect(notificationCenterMock.calls == [
            .stream(NSApplication.didBecomeActiveNotification),
            .stream(.AVAudioEngineConfigurationChange)
        ])
    }

    @Test
    mutating func startListening_emittedActivation_refreshesSetup() async {
        createSut()

        let tasks = sut.startListening()
        notificationCenterMock.emit(NSApplication.didBecomeActiveNotification)
        notificationCenterMock.finish(NSApplication.didBecomeActiveNotification)
        notificationCenterMock.finish(.AVAudioEngineConfigurationChange)
        for task in tasks { try? await task.value }

        #expect(await setupCheckerMock.calls == [.refresh])
    }

    @Test
    mutating func startListening_emittedConfigurationChange_refreshesSetup() async {
        createSut()

        let tasks = sut.startListening()
        notificationCenterMock.emit(.AVAudioEngineConfigurationChange)
        notificationCenterMock.finish(.AVAudioEngineConfigurationChange)
        notificationCenterMock.finish(NSApplication.didBecomeActiveNotification)
        for task in tasks { try? await task.value }

        #expect(await setupCheckerMock.calls == [.refresh])
    }
}
