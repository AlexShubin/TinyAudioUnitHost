//
//  AudioSettingsObserverTests.swift
//  SessionKitTests
//
//  Created by Alex Shubin on 08.10.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioSettingsKit
import AudioSettingsKitTestSupport
import Testing
@testable import SessionKit

@MainActor
@Suite
struct AudioSettingsObserverTests {
    var audioSettingsSpy: AudioSettingsModelSpy!
    var channelStripSpy: ChannelStripSpy!
    var midiConnectorSpy: MidiConnectorSpy!
    var sut: AudioSettingsObserverType!

    init() {
        audioSettingsSpy = AudioSettingsModelSpy()
        channelStripSpy = ChannelStripSpy()
        midiConnectorSpy = MidiConnectorSpy()
    }

    mutating func createSut() {
        sut = AudioSettingsObserver(
            audioSettings: audioSettingsSpy,
            channelStrip: channelStripSpy,
            midiConnector: midiConnectorSpy
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
    mutating func change_reconnectsChannelStripAndMidi() async {
        createSut()
        sut.start()
        audioSettingsSpy.settings = .fake(sampleRate: 48_000)

        await audioSettingsSpy.delegate?.audioSettingsDidChange()

        #expect(channelStripSpy.calls == [.reconnect])
        #expect(midiConnectorSpy.calls == [.reconnect(.fake())])
    }

    @Test
    mutating func change_sameAudioBindingTwice_reconnectsChannelStripOnce() async {
        createSut()
        sut.start()
        audioSettingsSpy.settings = .fake(sampleRate: 48_000)

        await audioSettingsSpy.delegate?.audioSettingsDidChange()
        await audioSettingsSpy.delegate?.audioSettingsDidChange()

        #expect(channelStripSpy.calls == [.reconnect])
        #expect(midiConnectorSpy.calls == [.reconnect(.fake()), .reconnect(.fake())])
    }

    @Test
    mutating func change_midiOnly_skipsChannelStripReconnect() async {
        createSut()
        sut.start()
        audioSettingsSpy.settings = .fake(sampleRate: 48_000)
        await audioSettingsSpy.delegate?.audioSettingsDidChange()

        audioSettingsSpy.settings = .fake(sampleRate: 48_000, selectedMidiDevices: [.fake(ref: 10)])
        await audioSettingsSpy.delegate?.audioSettingsDidChange()

        #expect(channelStripSpy.calls == [.reconnect])
        #expect(midiConnectorSpy.calls == [.reconnect(.fake()), .reconnect(.fake(sources: [10]))])
    }

    @Test
    mutating func change_targetDeviceOnly_reconnectsChannelStrip() async {
        createSut()
        sut.start()
        await audioSettingsSpy.delegate?.audioSettingsDidChange()

        audioSettingsSpy.targetDevice = .fake(id: 7)
        await audioSettingsSpy.delegate?.audioSettingsDidChange()

        #expect(channelStripSpy.calls == [.reconnect, .reconnect])
    }

    @Test
    mutating func change_setupOnly_reconnectsChannelStrip() async {
        audioSettingsSpy.setup = .unmet([.microphonePermission])
        createSut()
        sut.start()
        await audioSettingsSpy.delegate?.audioSettingsDidChange()

        audioSettingsSpy.setup = .met
        await audioSettingsSpy.delegate?.audioSettingsDidChange()

        #expect(channelStripSpy.calls == [.reconnect, .reconnect])
    }
}
