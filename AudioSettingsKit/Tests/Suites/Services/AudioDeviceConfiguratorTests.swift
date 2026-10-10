//
//  AudioDeviceConfiguratorTests.swift
//  AudioSettingsKitTests
//
//  Created by Alex Shubin on 09.10.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioSettingsKitTestSupport
import CoreAudioGatewayKit
import CoreAudioGatewayKitTestSupport
import Testing
@testable import AudioSettingsKit

@Suite
struct AudioDeviceConfiguratorTests {
    var gatewaySpy: CoreAudioGatewaySpy!
    var sut: AudioDeviceConfiguratorType!

    init() {
        gatewaySpy = CoreAudioGatewaySpy()
    }

    mutating func createSut() {
        sut = AudioDeviceConfigurator(gateway: gatewaySpy)
    }

    @Test
    mutating func apply_setsSampleRateThenBufferSize() {
        createSut()

        sut.apply(.fake(bufferSize: 256, sampleRate: 48_000), to: .fake(id: 7))

        #expect(gatewaySpy.calls == [.setSampleRate(48_000, 7), .setBufferSize(256, 7)])
    }

    @Test
    mutating func apply_withoutValues_setsNothing() {
        createSut()

        sut.apply(.fake(), to: .fake(id: 7))

        #expect(gatewaySpy.calls.isEmpty)
    }

    @Test
    mutating func apply_sampleRateFails_stillSetsBufferSize() {
        gatewaySpy.setSampleRateError = CoreAudioGatewayError(operation: .setSampleRate, status: -1)
        createSut()

        sut.apply(.fake(bufferSize: 256, sampleRate: 48_000), to: .fake(id: 7))

        #expect(gatewaySpy.calls == [.setSampleRate(48_000, 7), .setBufferSize(256, 7)])
    }
}
