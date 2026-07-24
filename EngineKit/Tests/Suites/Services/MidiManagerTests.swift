//
//  MidiManagerTests.swift
//  EngineKitTests
//
//  Created by Alex Shubin on 06.06.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioSettingsKitTestSupport
import AudioUnitsKit
import Testing
@testable import EngineKit

@Suite
struct MidiManagerTests {
    var coreMidiGatewayMock: CoreMidiGatewayMock!
    var audioSettingsMock: AudioSettingsProviderMock!
    var sut: MidiManagerType!

    init() {
        coreMidiGatewayMock = CoreMidiGatewayMock()
        audioSettingsMock = AudioSettingsProviderMock()
    }

    mutating func createSut() {
        sut = MidiManager(
            coreMidiGateway: coreMidiGatewayMock,
            audioSettings: audioSettingsMock
        )
    }

    // MARK: - setupMIDI

    @Test
    mutating func setupMIDI_createsClientAndInputPort_andConnectsSelectedSources() async {
        coreMidiGatewayMock.createClientResult = 1
        coreMidiGatewayMock.createInputPortResult = 2
        audioSettingsMock.settings = .fake(selectedMidiDevices: [.fake(ref: 10)])
        createSut()
        let audioUnit = AUAudioUnitWrapper()

        await sut.setupMIDI(for: audioUnit)

        #expect(coreMidiGatewayMock.calls == [
            .createClient("TinyAUHost"),
            .createInputPort(1, "Input", audioUnit),
            .connect(10, 2)
        ])
    }

    @Test
    mutating func setupMIDI_emptySelection_connectsNothing() async {
        coreMidiGatewayMock.createInputPortResult = 2
        createSut()
        let audioUnit = AUAudioUnitWrapper()

        await sut.setupMIDI(for: audioUnit)

        #expect(coreMidiGatewayMock.calls == [
            .createClient("TinyAUHost"),
            .createInputPort(1, "Input", audioUnit)
        ])
    }

    @Test
    mutating func setupMIDI_clientCreationFails_stopsBeforeInputPort() async {
        coreMidiGatewayMock.createClientResult = nil
        createSut()

        await sut.setupMIDI(for: AUAudioUnitWrapper())

        #expect(coreMidiGatewayMock.calls == [.createClient("TinyAUHost")])
    }

    @Test
    mutating func setupMIDI_inputPortCreationFails_doesNotConnectSources() async {
        coreMidiGatewayMock.createInputPortResult = nil
        audioSettingsMock.settings = .fake(selectedMidiDevices: [.fake(ref: 10)])
        createSut()
        let audioUnit = AUAudioUnitWrapper()

        await sut.setupMIDI(for: audioUnit)

        #expect(coreMidiGatewayMock.calls == [
            .createClient("TinyAUHost"),
            .createInputPort(1, "Input", audioUnit)
        ])
    }

    // MARK: - teardownMIDI

    @Test
    mutating func teardownMIDI_disposesInputPort() async {
        coreMidiGatewayMock.createInputPortResult = 2
        createSut()
        let audioUnit = AUAudioUnitWrapper()

        await sut.setupMIDI(for: audioUnit)
        await sut.teardownMIDI()

        #expect(coreMidiGatewayMock.calls == [
            .createClient("TinyAUHost"),
            .createInputPort(1, "Input", audioUnit),
            .disposePort(2)
        ])
    }

    // MARK: - reconnectMIDISources

    @Test
    mutating func reconnectMIDISources_selectionChanged_disconnectsOldAndConnectsNew() async {
        coreMidiGatewayMock.createInputPortResult = 2
        audioSettingsMock.settings = .fake(selectedMidiDevices: [.fake(ref: 10)])
        createSut()
        await sut.setupMIDI(for: AUAudioUnitWrapper())

        audioSettingsMock.settings = .fake(selectedMidiDevices: [.fake(ref: 20)])
        await sut.reconnectMIDISources()

        #expect(coreMidiGatewayMock.calls.suffix(2) == [
            .disconnect(10, 2),
            .connect(20, 2)
        ])
    }

    @Test
    mutating func reconnectMIDISources_selectionUnchanged_doesNothing() async {
        coreMidiGatewayMock.createInputPortResult = 2
        audioSettingsMock.settings = .fake(selectedMidiDevices: [.fake(ref: 10)])
        createSut()
        await sut.setupMIDI(for: AUAudioUnitWrapper())
        let callsAfterSetup = coreMidiGatewayMock.calls

        await sut.reconnectMIDISources()

        #expect(coreMidiGatewayMock.calls == callsAfterSetup)
    }

    @Test
    mutating func reconnectMIDISources_withoutInputPort_doesNothing() async {
        audioSettingsMock.settings = .fake(selectedMidiDevices: [.fake(ref: 10)])
        createSut()

        await sut.reconnectMIDISources()

        #expect(coreMidiGatewayMock.calls.isEmpty)
    }

    // MARK: - startListening

    @Test
    mutating func startListening_setupChangedAfterSetup_reappliesSelection() async {
        coreMidiGatewayMock.createInputPortResult = 2
        audioSettingsMock.settings = .fake(selectedMidiDevices: [.fake(ref: 10)])
        createSut()
        let audioUnit = AUAudioUnitWrapper()
        await sut.setupMIDI(for: audioUnit)
        audioSettingsMock.settings = .fake(selectedMidiDevices: [.fake(ref: 20)])

        let task = sut.startListening()
        coreMidiGatewayMock.setupChangesStream.continuation.yield()
        coreMidiGatewayMock.setupChangesStream.continuation.finish()
        try? await task.value

        #expect(coreMidiGatewayMock.calls == [
            .createClient("TinyAUHost"),
            .createInputPort(1, "Input", audioUnit),
            .connect(10, 2),
            .disconnect(10, 2),
            .connect(20, 2)
        ])
    }

    @Test
    mutating func startListening_setupChangedBeforeSetup_doesNotConnect() async {
        audioSettingsMock.settings = .fake(selectedMidiDevices: [.fake(ref: 10)])
        createSut()

        let task = sut.startListening()
        coreMidiGatewayMock.setupChangesStream.continuation.yield()
        coreMidiGatewayMock.setupChangesStream.continuation.finish()
        try? await task.value

        #expect(coreMidiGatewayMock.calls == [.createClient("TinyAUHost")])
    }
}
