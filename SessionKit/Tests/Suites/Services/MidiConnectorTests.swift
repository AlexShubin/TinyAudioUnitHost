//
//  MidiConnectorTests.swift
//  SessionKitTests
//
//  Created by Alex Shubin on 06.06.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioUnitsKit
import AudioUnitsKitTestSupport
import CoreMidiGatewayKitTestSupport
import SessionKitTestSupport
import Testing
@testable import SessionKit

@Suite
struct MidiConnectorTests {
    var coreMidiGatewaySpy: CoreMidiGatewaySpy!
    var sut: MidiConnectorType!

    init() {
        coreMidiGatewaySpy = CoreMidiGatewaySpy()
    }

    mutating func createSut() {
        sut = MidiConnector(coreMidiGateway: coreMidiGatewaySpy)
    }

    // MARK: - connect

    @Test
    mutating func connect_createsClientAndInputPort_andConnectsSources() {
        coreMidiGatewaySpy.createClientResult = 1
        coreMidiGatewaySpy.createInputPortResult = 2
        createSut()
        let audioUnit = LoadedAudioUnit(component: .fake())

        sut.connect(audioUnit, settings: .fake(sources: [10]))

        #expect(coreMidiGatewaySpy.calls == [
            .createClient("TinyAUHost"),
            .createInputPort(1, "Input", audioUnit),
            .connect(10, 2)
        ])
    }

    @Test
    mutating func connect_noSources_connectsNothing() {
        coreMidiGatewaySpy.createInputPortResult = 2
        createSut()
        let audioUnit = LoadedAudioUnit(component: .fake())

        sut.connect(audioUnit, settings: .fake())

        #expect(coreMidiGatewaySpy.calls == [
            .createClient("TinyAUHost"),
            .createInputPort(1, "Input", audioUnit)
        ])
    }

    @Test
    mutating func connect_clientCreationFails_stopsBeforeInputPort() {
        coreMidiGatewaySpy.createClientResult = nil
        createSut()

        sut.connect(LoadedAudioUnit(component: .fake()), settings: .fake())

        #expect(coreMidiGatewaySpy.calls == [.createClient("TinyAUHost")])
    }

    @Test
    mutating func connect_inputPortCreationFails_doesNotConnectSources() {
        coreMidiGatewaySpy.createInputPortResult = nil
        createSut()
        let audioUnit = LoadedAudioUnit(component: .fake())

        sut.connect(audioUnit, settings: .fake(sources: [10]))

        #expect(coreMidiGatewaySpy.calls == [
            .createClient("TinyAUHost"),
            .createInputPort(1, "Input", audioUnit)
        ])
    }

    @Test
    mutating func connect_twice_disposesPreviousPortFirst() {
        coreMidiGatewaySpy.createInputPortResult = 2
        createSut()
        let first = LoadedAudioUnit(component: .fake())
        let second = LoadedAudioUnit(component: .fake())
        sut.connect(first, settings: .fake())
        coreMidiGatewaySpy.createInputPortResult = 3

        sut.connect(second, settings: .fake())

        #expect(coreMidiGatewaySpy.calls == [
            .createClient("TinyAUHost"),
            .createInputPort(1, "Input", first),
            .disposePort(2),
            .createInputPort(1, "Input", second)
        ])
    }

    // MARK: - disconnect

    @Test
    mutating func disconnect_disposesInputPort() {
        coreMidiGatewaySpy.createInputPortResult = 2
        createSut()
        let audioUnit = LoadedAudioUnit(component: .fake())

        sut.connect(audioUnit, settings: .fake())
        sut.disconnect()

        #expect(coreMidiGatewaySpy.calls == [
            .createClient("TinyAUHost"),
            .createInputPort(1, "Input", audioUnit),
            .disposePort(2)
        ])
    }

    @Test
    mutating func disconnect_withoutPort_doesNothing() {
        createSut()

        sut.disconnect()

        #expect(coreMidiGatewaySpy.calls.isEmpty)
    }

    // MARK: - reconnect

    @Test
    mutating func reconnect_sourcesChanged_disconnectsOldAndConnectsNew() {
        coreMidiGatewaySpy.createInputPortResult = 2
        createSut()
        sut.connect(LoadedAudioUnit(component: .fake()), settings: .fake(sources: [10]))

        sut.reconnect(settings: .fake(sources: [20]))

        #expect(coreMidiGatewaySpy.calls.suffix(2) == [
            .disconnect(10, 2),
            .connect(20, 2)
        ])
    }

    @Test
    mutating func reconnect_sourcesUnchanged_doesNothing() {
        coreMidiGatewaySpy.createInputPortResult = 2
        createSut()
        sut.connect(LoadedAudioUnit(component: .fake()), settings: .fake(sources: [10]))
        let callsAfterConnect = coreMidiGatewaySpy.calls

        sut.reconnect(settings: .fake(sources: [10]))

        #expect(coreMidiGatewaySpy.calls == callsAfterConnect)
    }

    @Test
    mutating func reconnect_withoutInputPort_doesNothing() {
        createSut()

        sut.reconnect(settings: .fake(sources: [10]))

        #expect(coreMidiGatewaySpy.calls.isEmpty)
    }
}
