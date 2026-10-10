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

@Suite @MainActor
struct MidiManagerTests {
    var coreMidiGatewaySpy: CoreMidiGatewaySpy!
    var audioSettingsSpy: AudioSettingsModelSpy!
    var sut: MidiManagerType!

    init() {
        coreMidiGatewaySpy = CoreMidiGatewaySpy()
        audioSettingsSpy = AudioSettingsModelSpy()
    }

    mutating func createSut() {
        sut = MidiManager(
            coreMidiGateway: coreMidiGatewaySpy,
            audioSettings: audioSettingsSpy
        )
    }

    // MARK: - setupMIDI

    @Test
    mutating func setupMIDI_createsClientAndInputPort_andConnectsSelectedSources() async {
        coreMidiGatewaySpy.createClientResult = 1
        coreMidiGatewaySpy.createInputPortResult = 2
        audioSettingsSpy.settings = .fake(selectedMidiDevices: [.fake(ref: 10)])
        createSut()
        let audioUnit = AUAudioUnitWrapper()

        await sut.setupMIDI(for: audioUnit)

        #expect(coreMidiGatewaySpy.calls == [
            .createClient("TinyAUHost"),
            .createInputPort(1, "Input", audioUnit),
            .connect(10, 2)
        ])
    }

    @Test
    mutating func setupMIDI_emptySelection_connectsNothing() async {
        coreMidiGatewaySpy.createInputPortResult = 2
        createSut()
        let audioUnit = AUAudioUnitWrapper()

        await sut.setupMIDI(for: audioUnit)

        #expect(coreMidiGatewaySpy.calls == [
            .createClient("TinyAUHost"),
            .createInputPort(1, "Input", audioUnit)
        ])
    }

    @Test
    mutating func setupMIDI_clientCreationFails_stopsBeforeInputPort() async {
        coreMidiGatewaySpy.createClientResult = nil
        createSut()

        await sut.setupMIDI(for: AUAudioUnitWrapper())

        #expect(coreMidiGatewaySpy.calls == [.createClient("TinyAUHost")])
    }

    @Test
    mutating func setupMIDI_inputPortCreationFails_doesNotConnectSources() async {
        coreMidiGatewaySpy.createInputPortResult = nil
        audioSettingsSpy.settings = .fake(selectedMidiDevices: [.fake(ref: 10)])
        createSut()
        let audioUnit = AUAudioUnitWrapper()

        await sut.setupMIDI(for: audioUnit)

        #expect(coreMidiGatewaySpy.calls == [
            .createClient("TinyAUHost"),
            .createInputPort(1, "Input", audioUnit)
        ])
    }

    // MARK: - teardownMIDI

    @Test
    mutating func teardownMIDI_disposesInputPort() async {
        coreMidiGatewaySpy.createInputPortResult = 2
        createSut()
        let audioUnit = AUAudioUnitWrapper()

        await sut.setupMIDI(for: audioUnit)
        await sut.teardownMIDI()

        #expect(coreMidiGatewaySpy.calls == [
            .createClient("TinyAUHost"),
            .createInputPort(1, "Input", audioUnit),
            .disposePort(2)
        ])
    }

    // MARK: - reconnectMIDISources

    @Test
    mutating func reconnectMIDISources_selectionChanged_disconnectsOldAndConnectsNew() async {
        coreMidiGatewaySpy.createInputPortResult = 2
        audioSettingsSpy.settings = .fake(selectedMidiDevices: [.fake(ref: 10)])
        createSut()
        await sut.setupMIDI(for: AUAudioUnitWrapper())

        audioSettingsSpy.settings = .fake(selectedMidiDevices: [.fake(ref: 20)])
        await sut.reconnectMIDISources()

        #expect(coreMidiGatewaySpy.calls.suffix(2) == [
            .disconnect(10, 2),
            .connect(20, 2)
        ])
    }

    @Test
    mutating func reconnectMIDISources_selectionUnchanged_doesNothing() async {
        coreMidiGatewaySpy.createInputPortResult = 2
        audioSettingsSpy.settings = .fake(selectedMidiDevices: [.fake(ref: 10)])
        createSut()
        await sut.setupMIDI(for: AUAudioUnitWrapper())
        let callsAfterSetup = coreMidiGatewaySpy.calls

        await sut.reconnectMIDISources()

        #expect(coreMidiGatewaySpy.calls == callsAfterSetup)
    }

    @Test
    mutating func reconnectMIDISources_withoutInputPort_doesNothing() async {
        audioSettingsSpy.settings = .fake(selectedMidiDevices: [.fake(ref: 10)])
        createSut()

        await sut.reconnectMIDISources()

        #expect(coreMidiGatewaySpy.calls.isEmpty)
    }

}
