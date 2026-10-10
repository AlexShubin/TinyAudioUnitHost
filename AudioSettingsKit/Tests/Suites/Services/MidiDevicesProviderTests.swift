//
//  MidiDevicesProviderTests.swift
//  AudioSettingsKitTests
//
//  Created by Alex Shubin on 02.07.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import CoreMidiGatewayKitTestSupport
import Testing
@testable import AudioSettingsKit

@Suite
struct MidiDevicesProviderTests {
    var gatewaySpy: CoreMidiGatewaySpy!
    var sut: MidiDevicesProviderType!

    init() {
        gatewaySpy = CoreMidiGatewaySpy()
    }

    mutating func createSut() {
        sut = MidiDevicesProvider(gateway: gatewaySpy)
    }

    @Test
    mutating func devices_enumeratesEverySourceIntoDevice() {
        gatewaySpy.sourceCountResult = 2
        gatewaySpy.sourcesByIndex = [0: 10, 1: 20]
        gatewaySpy.displayNameBySource = [10: "Keystep", 20: "Push"]
        gatewaySpy.uidBySource = [10: 100, 20: 200]
        createSut()

        #expect(sut.devices == [
            MidiDevice(ref: 10, uid: 100, name: "Keystep"),
            MidiDevice(ref: 20, uid: 200, name: "Push")
        ])
    }

    @Test
    mutating func devices_skipsSourceMissingUID() {
        gatewaySpy.sourceCountResult = 2
        gatewaySpy.sourcesByIndex = [0: 10, 1: 20]
        gatewaySpy.displayNameBySource = [10: "Keystep", 20: "Push"]
        gatewaySpy.uidBySource = [10: 100] // source 20 has no UID
        createSut()

        #expect(sut.devices == [MidiDevice(ref: 10, uid: 100, name: "Keystep")])
    }

    @Test
    mutating func devices_skipsSourceMissingName() {
        gatewaySpy.sourceCountResult = 2
        gatewaySpy.sourcesByIndex = [0: 10, 1: 20]
        gatewaySpy.displayNameBySource = [10: "Keystep"] // source 20 has no name
        gatewaySpy.uidBySource = [10: 100, 20: 200]
        createSut()

        #expect(sut.devices == [MidiDevice(ref: 10, uid: 100, name: "Keystep")])
    }

    @Test
    mutating func devices_skipsOfflineSources() {
        gatewaySpy.sourceCountResult = 2
        gatewaySpy.sourcesByIndex = [0: 10, 1: 20]
        gatewaySpy.displayNameBySource = [10: "Keystep", 20: "Push"]
        gatewaySpy.uidBySource = [10: 100, 20: 200]
        gatewaySpy.offlineSources = [20]
        createSut()

        #expect(sut.devices == [MidiDevice(ref: 10, uid: 100, name: "Keystep")])
    }

    @Test
    mutating func devices_emptyWhenNoSources() {
        gatewaySpy.sourceCountResult = 0
        createSut()

        #expect(sut.devices.isEmpty)
    }
}
