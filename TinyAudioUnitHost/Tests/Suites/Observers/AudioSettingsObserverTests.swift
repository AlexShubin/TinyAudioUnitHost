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
    var pluginChainSpy: PluginChainSpy!
    var midiManagerSpy: MidiManagerSpy!
    var sut: AudioSettingsObserverType!

    init() {
        audioSettingsSpy = AudioSettingsModelSpy()
        pluginChainSpy = PluginChainSpy()
        midiManagerSpy = MidiManagerSpy()
    }

    mutating func createSut() {
        sut = AudioSettingsObserver(
            audioSettings: audioSettingsSpy,
            pluginChain: pluginChainSpy,
            midiManager: midiManagerSpy
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
    mutating func change_reconnectsPluginChainAndMidi() async {
        createSut()
        sut.start()
        audioSettingsSpy.settings = .fake(sampleRate: 48_000)

        await audioSettingsSpy.delegate?.audioSettingsDidChange()

        #expect(pluginChainSpy.calls == [.reconnect])
        #expect(midiManagerSpy.calls == [.reconnectMIDISources])
    }

    @Test
    mutating func change_sameAudioBindingTwice_reconnectsPluginChainOnce() async {
        createSut()
        sut.start()
        audioSettingsSpy.settings = .fake(sampleRate: 48_000)

        await audioSettingsSpy.delegate?.audioSettingsDidChange()
        await audioSettingsSpy.delegate?.audioSettingsDidChange()

        #expect(pluginChainSpy.calls == [.reconnect])
        #expect(midiManagerSpy.calls == [.reconnectMIDISources, .reconnectMIDISources])
    }

    @Test
    mutating func change_midiOnly_skipsPluginChainReconnect() async {
        createSut()
        sut.start()
        audioSettingsSpy.settings = .fake(sampleRate: 48_000)
        await audioSettingsSpy.delegate?.audioSettingsDidChange()

        audioSettingsSpy.settings = .fake(sampleRate: 48_000, selectedMidiDevices: [.fake()])
        await audioSettingsSpy.delegate?.audioSettingsDidChange()

        #expect(pluginChainSpy.calls == [.reconnect])
        #expect(midiManagerSpy.calls == [.reconnectMIDISources, .reconnectMIDISources])
    }

    @Test
    mutating func change_targetDeviceOnly_reconnectsPluginChain() async {
        createSut()
        sut.start()
        await audioSettingsSpy.delegate?.audioSettingsDidChange()

        audioSettingsSpy.targetDevice = .fake(id: 7)
        await audioSettingsSpy.delegate?.audioSettingsDidChange()

        #expect(pluginChainSpy.calls == [.reconnect, .reconnect])
    }

    @Test
    mutating func change_setupOnly_reconnectsPluginChain() async {
        audioSettingsSpy.setup = .unmet([.microphonePermission])
        createSut()
        sut.start()
        await audioSettingsSpy.delegate?.audioSettingsDidChange()

        audioSettingsSpy.setup = .met
        await audioSettingsSpy.delegate?.audioSettingsDidChange()

        #expect(pluginChainSpy.calls == [.reconnect, .reconnect])
    }
}
