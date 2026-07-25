//
//  MidiDevicesProviderTests.swift
//  AudioSettingsKitTests
//
//  Created by Alex Shubin on 02.07.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import Testing
@testable import AudioSettingsKit

@Suite
struct MidiDevicesProviderTests {
    var gatewayMock: CoreMidiGatewayMock!
    var sut: MidiDevicesProviderType!

    init() {
        gatewayMock = CoreMidiGatewayMock()
    }

    mutating func createSut() {
        sut = MidiDevicesProvider(gateway: gatewayMock)
    }

    @Test
    mutating func devices_enumeratesEverySourceIntoDevice() {
        gatewayMock.sourceCountResult = 2
        gatewayMock.sourcesByIndex = [0: 10, 1: 20]
        gatewayMock.displayNameBySource = [10: "Keystep", 20: "Push"]
        gatewayMock.uidBySource = [10: 100, 20: 200]
        createSut()

        #expect(sut.devices == [
            MidiDevice(ref: 10, uid: 100, name: "Keystep"),
            MidiDevice(ref: 20, uid: 200, name: "Push")
        ])
    }

    @Test
    mutating func devices_skipsSourceMissingUID() {
        gatewayMock.sourceCountResult = 2
        gatewayMock.sourcesByIndex = [0: 10, 1: 20]
        gatewayMock.displayNameBySource = [10: "Keystep", 20: "Push"]
        gatewayMock.uidBySource = [10: 100] // source 20 has no UID
        createSut()

        #expect(sut.devices == [MidiDevice(ref: 10, uid: 100, name: "Keystep")])
    }

    @Test
    mutating func devices_skipsSourceMissingName() {
        gatewayMock.sourceCountResult = 2
        gatewayMock.sourcesByIndex = [0: 10, 1: 20]
        gatewayMock.displayNameBySource = [10: "Keystep"] // source 20 has no name
        gatewayMock.uidBySource = [10: 100, 20: 200]
        createSut()

        #expect(sut.devices == [MidiDevice(ref: 10, uid: 100, name: "Keystep")])
    }

    @Test
    mutating func devices_skipsOfflineSources() {
        gatewayMock.sourceCountResult = 2
        gatewayMock.sourcesByIndex = [0: 10, 1: 20]
        gatewayMock.displayNameBySource = [10: "Keystep", 20: "Push"]
        gatewayMock.uidBySource = [10: 100, 20: 200]
        gatewayMock.offlineSources = [20]
        createSut()

        #expect(sut.devices == [MidiDevice(ref: 10, uid: 100, name: "Keystep")])
    }

    @Test
    mutating func devices_emptyWhenNoSources() {
        gatewayMock.sourceCountResult = 0
        createSut()

        #expect(sut.devices.isEmpty)
    }
}
