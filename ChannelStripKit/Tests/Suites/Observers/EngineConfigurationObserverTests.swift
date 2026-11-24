//
//  EngineConfigurationObserverTests.swift
//  ChannelStripKitTests
//
//  Created by Alex Shubin on 24.11.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AVFoundation
import CommonTestSupport
import Testing
@testable import ChannelStripKit

@MainActor
@Suite
struct EngineConfigurationObserverTests {
    var channelStripSpy: ChannelStripSpy!
    var notificationCenterSpy: NotificationCenterSpy!
    var sut: EngineConfigurationObserver!

    init() {
        channelStripSpy = ChannelStripSpy()
        notificationCenterSpy = NotificationCenterSpy()
    }

    mutating func createSut() {
        sut = EngineConfigurationObserver(
            channelStrip: channelStripSpy,
            notificationCenter: notificationCenterSpy
        )
    }

    @Test
    mutating func init_observesEngineConfigurationChange() {
        createSut()

        #expect(notificationCenterSpy.calls == [.observe(.AVAudioEngineConfigurationChange)])
    }

    @Test
    mutating func configurationChange_reconnectsChannelStrip() async {
        createSut()

        await notificationCenterSpy.handlers[.AVAudioEngineConfigurationChange]?()

        #expect(channelStripSpy.calls == [.reconnect])
    }
}
