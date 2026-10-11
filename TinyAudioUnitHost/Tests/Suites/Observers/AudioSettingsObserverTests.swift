//
//  AudioSettingsObserverTests.swift
//  TinyAudioUnitHostTests
//
//  Created by Alex Shubin on 08.10.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioSettingsKit
import AudioSettingsKitTestSupport
import EngineKitTestSupport
import Testing
@testable import TinyAudioUnitHost

@MainActor
@Suite
struct AudioSettingsObserverTests {
    var audioSettingsSpy: AudioSettingsModelSpy!
    var engineSpy: EngineSpy!
    var midiManagerSpy: MidiManagerSpy!
    var sessionSpy: SessionModelSpy!
    var sut: AudioSettingsObserverType!

    init() {
        audioSettingsSpy = AudioSettingsModelSpy()
        engineSpy = EngineSpy()
        midiManagerSpy = MidiManagerSpy()
        sessionSpy = SessionModelSpy()
    }

    mutating func createSut() {
        sut = AudioSettingsObserver(
            audioSettings: audioSettingsSpy,
            engine: engineSpy,
            midiManager: midiManagerSpy,
            session: sessionSpy
        )
    }

    // MARK: - start

    @Test
    mutating func start_becomesModelDelegate() {
        createSut()

        sut.start()

        #expect(audioSettingsSpy.delegate === sut)
    }

    // MARK: - audio settings change

    @Test
    mutating func change_reloadsEngineAndReconnectsMidi() async {
        createSut()
        sut.start()
        audioSettingsSpy.settings = .fake(sampleRate: 48_000)

        await audioSettingsSpy.delegate?.audioSettingsDidChange()

        #expect(engineSpy.calls == [.reload])
        #expect(midiManagerSpy.calls == [.reconnectMIDISources])
    }

    @Test
    mutating func change_setupMet_startsSession() async {
        audioSettingsSpy.setup = .met
        createSut()
        sut.start()

        await audioSettingsSpy.delegate?.audioSettingsDidChange()

        #expect(sessionSpy.calls == [.start])
    }

    @Test
    mutating func change_setupUnmet_stopsSession() async {
        audioSettingsSpy.setup = .unmet([.noOutputDevice])
        createSut()
        sut.start()

        await audioSettingsSpy.delegate?.audioSettingsDidChange()

        #expect(sessionSpy.calls == [.stop])
    }

    @Test
    mutating func change_setupChecking_leavesSessionAlone() async {
        createSut()
        sut.start()

        await audioSettingsSpy.delegate?.audioSettingsDidChange()

        #expect(sessionSpy.calls.isEmpty)
    }

    @Test
    mutating func change_sameAudioBindingTwice_reloadsEngineOnce() async {
        createSut()
        sut.start()
        audioSettingsSpy.settings = .fake(sampleRate: 48_000)

        await audioSettingsSpy.delegate?.audioSettingsDidChange()
        await audioSettingsSpy.delegate?.audioSettingsDidChange()

        #expect(engineSpy.calls == [.reload])
        #expect(midiManagerSpy.calls == [.reconnectMIDISources, .reconnectMIDISources])
    }

    @Test
    mutating func change_midiOnly_skipsEngineReload() async {
        createSut()
        sut.start()
        audioSettingsSpy.settings = .fake(sampleRate: 48_000)
        await audioSettingsSpy.delegate?.audioSettingsDidChange()

        audioSettingsSpy.settings = .fake(sampleRate: 48_000, selectedMidiDevices: [.fake()])
        await audioSettingsSpy.delegate?.audioSettingsDidChange()

        #expect(engineSpy.calls == [.reload])
        #expect(midiManagerSpy.calls == [.reconnectMIDISources, .reconnectMIDISources])
    }

    @Test
    mutating func change_targetDeviceOnly_reloadsEngine() async {
        createSut()
        sut.start()
        await audioSettingsSpy.delegate?.audioSettingsDidChange()

        audioSettingsSpy.targetDevice = .fake(id: 7)
        await audioSettingsSpy.delegate?.audioSettingsDidChange()

        #expect(engineSpy.calls == [.reload, .reload])
    }
}
