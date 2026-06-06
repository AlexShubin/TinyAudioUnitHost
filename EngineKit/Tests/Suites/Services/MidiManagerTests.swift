//
//  MidiManagerTests.swift
//  EngineKitTests
//
//  Created by Alex Shubin on 06.06.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioUnitsKit
import AudioUnitsKitTestSupport
import Testing
@testable import EngineKit

@Suite
struct MidiManagerTests {
    var coreMidiGatewayMock: CoreMidiGatewayMock!
    var sut: MidiManagerType!

    init() {
        coreMidiGatewayMock = CoreMidiGatewayMock()
    }

    mutating func createSut() {
        sut = MidiManager(coreMidiGateway: coreMidiGatewayMock)
    }

    // MARK: - setupMIDI

    @Test
    mutating func setupMIDI_createsClientAndInputPort_andConnectsAllSources() async {
        coreMidiGatewayMock.createClientResult = 1
        coreMidiGatewayMock.createInputPortResult = 2
        coreMidiGatewayMock.sources = [10, 20]
        createSut()
        let audioUnit = AUAudioUnitMock()

        await sut.setupMIDI(for: audioUnit)

        #expect(coreMidiGatewayMock.calls == [
            .createClient("TinyAUHost"),
            .createInputPort(1, "Input"),
            .source(0), .connect(10, 2),
            .source(1), .connect(20, 2)
        ])
        #expect(coreMidiGatewayMock.createInputPortAudioUnit === audioUnit)
    }

    @Test
    mutating func setupMIDI_clientCreationFails_stopsBeforeInputPort() async {
        coreMidiGatewayMock.createClientResult = nil
        createSut()

        await sut.setupMIDI(for: AUAudioUnitMock())

        #expect(coreMidiGatewayMock.calls == [.createClient("TinyAUHost")])
    }

    @Test
    mutating func setupMIDI_inputPortCreationFails_doesNotConnectSources() async {
        coreMidiGatewayMock.createInputPortResult = nil
        coreMidiGatewayMock.sources = [10]
        createSut()

        await sut.setupMIDI(for: AUAudioUnitMock())

        #expect(coreMidiGatewayMock.calls == [
            .createClient("TinyAUHost"),
            .createInputPort(1, "Input")
        ])
    }

    // MARK: - teardownMIDI

    @Test
    mutating func teardownMIDI_disposesInputPort() async {
        coreMidiGatewayMock.createInputPortResult = 2
        coreMidiGatewayMock.sources = []
        createSut()

        await sut.setupMIDI(for: AUAudioUnitMock())
        await sut.teardownMIDI()

        #expect(coreMidiGatewayMock.calls == [
            .createClient("TinyAUHost"),
            .createInputPort(1, "Input"),
            .disposePort(2)
        ])
    }

    // MARK: - startListening

    @Test
    mutating func startListening_setupChangedAfterSetup_reconnectsAllSources() async {
        coreMidiGatewayMock.createInputPortResult = 2
        coreMidiGatewayMock.sources = [10]
        createSut()
        await sut.setupMIDI(for: AUAudioUnitMock())

        let task = sut.startListening()
        coreMidiGatewayMock.emitSetupChanged()
        coreMidiGatewayMock.finishSetupChanges()
        try? await task.value

        #expect(coreMidiGatewayMock.calls == [
            .createClient("TinyAUHost"),
            .createInputPort(1, "Input"),
            .source(0), .connect(10, 2),
            .source(0), .connect(10, 2)
        ])
    }

    @Test
    mutating func startListening_setupChangedBeforeSetup_doesNotConnect() async {
        coreMidiGatewayMock.sources = [10]
        createSut()

        let task = sut.startListening()
        coreMidiGatewayMock.emitSetupChanged()
        coreMidiGatewayMock.finishSetupChanges()
        try? await task.value

        #expect(coreMidiGatewayMock.calls == [.createClient("TinyAUHost")])
    }
}
