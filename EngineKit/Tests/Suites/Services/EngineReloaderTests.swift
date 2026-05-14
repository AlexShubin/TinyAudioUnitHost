//
//  EngineReloaderTests.swift
//  EngineKitTests
//
//  Created by Alex Shubin on 14.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AppKit
import AVFoundation
import EngineKitTestSupport
import Testing
@testable import EngineKit

@Suite
struct EngineReloaderTests {
    var engineMock: EngineMock!
    var notificationCenterMock: NotificationCenterMock!
    var workspaceNotificationCenterMock: NotificationCenterMock!
    var sut: EngineReloader!

    init() {
        engineMock = EngineMock()
        notificationCenterMock = NotificationCenterMock()
        workspaceNotificationCenterMock = NotificationCenterMock()
    }

    mutating func createSut() {
        sut = EngineReloader(
            engine: engineMock,
            notificationCenter: notificationCenterMock,
            workspaceNotificationCenter: workspaceNotificationCenterMock
        )
    }

    @Test
    mutating func startListening_audioEngineConfigurationChange_subscribesOnDefaultCenter() {
        createSut()

        sut.startListening(to: .audioEngineConfigurationChange)

        #expect(notificationCenterMock.calls == [.stream(.AVAudioEngineConfigurationChange)])
        #expect(workspaceNotificationCenterMock.calls == [])
    }

    @Test
    mutating func startListening_workspaceDidWake_subscribesOnWorkspaceCenter() {
        createSut()

        sut.startListening(to: .workspaceDidWake)

        #expect(workspaceNotificationCenterMock.calls == [.stream(NSWorkspace.didWakeNotification)])
        #expect(notificationCenterMock.calls == [])
    }

    @Test
    mutating func startListening_audioEngineConfigurationChange_emitted_callsEngineReload() async {
        createSut()

        let task = sut.startListening(to: .audioEngineConfigurationChange)
        notificationCenterMock.emit(.AVAudioEngineConfigurationChange)
        notificationCenterMock.finish(.AVAudioEngineConfigurationChange)
        try? await task.value

        #expect(await engineMock.calls == [.reload])
    }

    @Test
    mutating func startListening_workspaceDidWake_emitted_callsEngineReload() async {
        createSut()

        let task = sut.startListening(to: .workspaceDidWake)
        workspaceNotificationCenterMock.emit(NSWorkspace.didWakeNotification)
        workspaceNotificationCenterMock.finish(NSWorkspace.didWakeNotification)
        try? await task.value

        #expect(await engineMock.calls == [.reload])
    }
}
