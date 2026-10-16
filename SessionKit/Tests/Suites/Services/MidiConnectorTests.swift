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
import Testing
@testable import SessionKit

@Suite @MainActor
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
    mutating func connect_createsClientAndInputPort_andConnectsSources() async {
        coreMidiGatewaySpy.createClientResult = 1
        coreMidiGatewaySpy.createInputPortResult = 2
        createSut()
        let audioUnit = LoadedAudioUnit(component: .fake())

        await sut.connect(audioUnit, settings: .fake(sources: [10]))

        #expect(coreMidiGatewaySpy.calls == [
            .createClient("TinyAUHost"),
            .createInputPort(1, "Input", audioUnit),
            .connect(10, 2)
        ])
    }

    @Test
    mutating func connect_noSources_connectsNothing() async {
        coreMidiGatewaySpy.createInputPortResult = 2
        createSut()
        let audioUnit = LoadedAudioUnit(component: .fake())

        await sut.connect(audioUnit, settings: .fake())

        #expect(coreMidiGatewaySpy.calls == [
            .createClient("TinyAUHost"),
            .createInputPort(1, "Input", audioUnit)
        ])
    }

    @Test
    mutating func connect_clientCreationFails_stopsBeforeInputPort() async {
        coreMidiGatewaySpy.createClientResult = nil
        createSut()

        await sut.connect(LoadedAudioUnit(component: .fake()), settings: .fake())

        #expect(coreMidiGatewaySpy.calls == [.createClient("TinyAUHost")])
    }

    @Test
    mutating func connect_inputPortCreationFails_doesNotConnectSources() async {
        coreMidiGatewaySpy.createInputPortResult = nil
        createSut()
        let audioUnit = LoadedAudioUnit(component: .fake())

        await sut.connect(audioUnit, settings: .fake(sources: [10]))

        #expect(coreMidiGatewaySpy.calls == [
            .createClient("TinyAUHost"),
            .createInputPort(1, "Input", audioUnit)
        ])
    }

    @Test
    mutating func connect_twice_disposesPreviousPortFirst() async {
        coreMidiGatewaySpy.createInputPortResult = 2
        createSut()
        let first = LoadedAudioUnit(component: .fake())
        let second = LoadedAudioUnit(component: .fake())
        await sut.connect(first, settings: .fake())
        coreMidiGatewaySpy.createInputPortResult = 3

        await sut.connect(second, settings: .fake())

        #expect(coreMidiGatewaySpy.calls == [
            .createClient("TinyAUHost"),
            .createInputPort(1, "Input", first),
            .disposePort(2),
            .createInputPort(1, "Input", second)
        ])
    }

    // MARK: - disconnect

    @Test
    mutating func disconnect_disposesInputPort() async {
        coreMidiGatewaySpy.createInputPortResult = 2
        createSut()
        let audioUnit = LoadedAudioUnit(component: .fake())

        await sut.connect(audioUnit, settings: .fake())
        await sut.disconnect()

        #expect(coreMidiGatewaySpy.calls == [
            .createClient("TinyAUHost"),
            .createInputPort(1, "Input", audioUnit),
            .disposePort(2)
        ])
    }

    @Test
    mutating func disconnect_withoutPort_doesNothing() async {
        createSut()

        await sut.disconnect()

        #expect(coreMidiGatewaySpy.calls.isEmpty)
    }

    // MARK: - reconnect

    @Test
    mutating func reconnect_sourcesChanged_disconnectsOldAndConnectsNew() async {
        coreMidiGatewaySpy.createInputPortResult = 2
        createSut()
        await sut.connect(LoadedAudioUnit(component: .fake()), settings: .fake(sources: [10]))

        await sut.reconnect(settings: .fake(sources: [20]))

        #expect(coreMidiGatewaySpy.calls.suffix(2) == [
            .disconnect(10, 2),
            .connect(20, 2)
        ])
    }

    @Test
    mutating func reconnect_sourcesUnchanged_doesNothing() async {
        coreMidiGatewaySpy.createInputPortResult = 2
        createSut()
        await sut.connect(LoadedAudioUnit(component: .fake()), settings: .fake(sources: [10]))
        let callsAfterConnect = coreMidiGatewaySpy.calls

        await sut.reconnect(settings: .fake(sources: [10]))

        #expect(coreMidiGatewaySpy.calls == callsAfterConnect)
    }

    @Test
    mutating func reconnect_withoutInputPort_doesNothing() async {
        createSut()

        await sut.reconnect(settings: .fake(sources: [10]))

        #expect(coreMidiGatewaySpy.calls.isEmpty)
    }
}
