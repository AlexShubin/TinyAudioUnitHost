//
//  EngineReloaderTests.swift
//  EngineKitTests
//
//  Created by Alex Shubin on 14.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

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
    mutating func startListening_subscribesToAVAudioEngineConfigurationChange() {
        createSut()

        _ = sut.startListening()

        #expect(notificationCenterMock.calls == [.stream(.AVAudioEngineConfigurationChange)])
    }

    @Test
    mutating func startListening_processesEmittedConfigChanges_callsEngineReload() async {
        createSut()

        let task = sut.startListening()
        notificationCenterMock.emit(.AVAudioEngineConfigurationChange)
        notificationCenterMock.finish(.AVAudioEngineConfigurationChange)
        try? await task.value

        #expect(await engineMock.calls == [.reload])
    }
}
