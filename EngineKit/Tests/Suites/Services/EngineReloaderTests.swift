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
    var sut: EngineReloader!

    init() {
        engineMock = EngineMock()
        notificationCenterMock = NotificationCenterMock()
    }

    mutating func createSut() {
        sut = EngineReloader(engine: engineMock, notificationCenter: notificationCenterMock)
    }

    @Test
    mutating func startListening_audioEngineConfigurationChange_subscribesToCorrectNotification() {
        createSut()

        sut.startListening(to: .audioEngineConfigurationChange)

        #expect(notificationCenterMock.calls == [.stream(.AVAudioEngineConfigurationChange)])
    }

    @Test
    mutating func startListening_workspaceDidWake_subscribesToCorrectNotification() {
        createSut()

        sut.startListening(to: .workspaceDidWake)

        #expect(notificationCenterMock.calls == [.stream(NSWorkspace.didWakeNotification)])
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
        notificationCenterMock.emit(NSWorkspace.didWakeNotification)
        notificationCenterMock.finish(NSWorkspace.didWakeNotification)
        try? await task.value

        #expect(await engineMock.calls == [.reload])
    }
}
