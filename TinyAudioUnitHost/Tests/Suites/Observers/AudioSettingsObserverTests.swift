//
//  AudioSettingsObserverTests.swift
//  TinyAudioUnitHostTests
//
//  Created by Alex Shubin on 08.10.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioSettingsKit
import AudioSettingsKitTestSupport
import SessionKit
import SessionKitTestSupport
import Testing
@testable import TinyAudioUnitHost

@MainActor
@Suite
struct AudioSettingsObserverTests {
    var audioSettingsSpy: AudioSettingsModelSpy!
    var sessionSpy: SessionModelSpy!
    var sut: AudioSettingsObserver!

    init() {
        audioSettingsSpy = AudioSettingsModelSpy()
        sessionSpy = SessionModelSpy()
    }

    mutating func createSut() {
        sut = AudioSettingsObserver(audioSettings: audioSettingsSpy, session: sessionSpy)
    }

    // MARK: - init

    @Test
    mutating func init_becomesModelDelegate() {
        createSut()

        #expect(audioSettingsSpy.delegate === sut)
    }

    // MARK: - audio settings change

    @Test
    mutating func change_setupMet_updatesSessionWithHardwareSettings() async {
        audioSettingsSpy.setup = .met
        audioSettingsSpy.targetDevice = .fake(id: 7)
        audioSettingsSpy.settings = .fake(
            inputDevice: .fake(id: 3, outputChannels: [.fake(id: 1), .fake(id: 2)]),
            outputDevice: .fake(id: 4),
            inputChannel: .mono(.fake(id: 2)),
            outputChannel: .stereo(l: .fake(id: 1), r: .fake(id: 2)),
            sampleRate: 48_000,
            selectedMidiDevices: [.fake(ref: 10)]
        )
        createSut()

        await audioSettingsSpy.delegate?.audioSettingsDidChange()

        #expect(sessionSpy.calls == [.updateHardwareSettings(.fake(
            audio: .fake(
                deviceID: 7,
                inputDevice: .fake(id: 3, outputChannelCount: 2),
                outputDevice: .fake(id: 4, outputChannelCount: 0),
                inputChannels: [2],
                outputChannels: [1, 2],
                sampleRate: 48_000
            ),
            midi: .fake(sources: [10])
        ))])
    }

    @Test
    mutating func change_setupNotMet_updatesSessionWithoutSettings() async {
        audioSettingsSpy.setup = .unmet([.microphonePermission])
        audioSettingsSpy.targetDevice = .fake()
        createSut()

        await audioSettingsSpy.delegate?.audioSettingsDidChange()

        #expect(sessionSpy.calls == [.updateHardwareSettings(nil)])
    }

    @Test
    mutating func change_withoutTargetDevice_updatesSessionWithoutSettings() async {
        audioSettingsSpy.setup = .met
        createSut()

        await audioSettingsSpy.delegate?.audioSettingsDidChange()

        #expect(sessionSpy.calls == [.updateHardwareSettings(nil)])
    }
}
