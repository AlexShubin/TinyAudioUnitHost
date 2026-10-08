//
//  SettingsPresenterTests.swift
//  TinyAudioUnitHostTests
//
//  Created by Alex Shubin on 19.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioSettingsKit
import AudioSettingsKitTestSupport
import Testing
@testable import TinyAudioUnitHost

@MainActor
@Suite
struct SettingsPresenterTests {
    var audioSettingsSpy: AudioSettingsModelSpy!
    var sut: SettingsPresenter!

    init() {
        audioSettingsSpy = AudioSettingsModelSpy()
    }

    mutating func createSut() {
        sut = SettingsPresenter(audioSettings: audioSettingsSpy)
    }

    // MARK: - projections

    @Test
    mutating func pickerStates_projectModelDevicesAndSettings() {
        let inDevice = AudioDevice.fake(id: 1, uid: "in", inputChannels: [.fake(id: 1)])
        let outDevice = AudioDevice.fake(id: 2, uid: "out", outputChannels: [.fake(id: 1)])
        audioSettingsSpy.inputDevices = [inDevice]
        audioSettingsSpy.outputDevices = [outDevice]
        audioSettingsSpy.settings = .fake(
            inputDevice: inDevice,
            outputDevice: outDevice,
            inputChannel: .mono(.fake(id: 1)),
            outputChannel: .mono(.fake(id: 1))
        )
        createSut()

        #expect(sut.inputState == DevicePickerState(devices: [inDevice], selectedDevice: inDevice, selectedChannel: .mono(.fake(id: 1))))
        #expect(sut.outputState == DevicePickerState(devices: [outDevice], selectedDevice: outDevice, selectedChannel: .mono(.fake(id: 1))))
        #expect(audioSettingsSpy.calls.isEmpty)
    }

    @Test
    mutating func midiState_projectsModelDevicesAndSelection() {
        let selected = MidiDevice.fake(ref: 10, uid: 100, name: "Keystep")
        let other = MidiDevice.fake(ref: 20, uid: 200, name: "Push")
        audioSettingsSpy.midiDevices = [selected, other]
        audioSettingsSpy.settings = .fake(selectedMidiDevices: [selected])
        createSut()

        #expect(sut.midiState == MidiDevicePickerState(devices: [selected, other], selectedDevices: [selected]))
    }

    @Test
    mutating func bufferAndSampleRate_projectSettingsAndTarget() {
        audioSettingsSpy.settings = .fake(bufferSize: 64, sampleRate: 44_100)
        audioSettingsSpy.targetDevice = .fake(availableBufferSizes: [32, 64, 128], availableSampleRates: [44_100, 48_000])
        createSut()

        #expect(sut.bufferSize == 64)
        #expect(sut.availableBufferSizes == [32, 64, 128])
        #expect(sut.sampleRate == 44_100)
        #expect(sut.availableSampleRates == [44_100, 48_000])
    }

    @Test
    mutating func noTarget_projectsStoredValuesAndEmptyLists() {
        audioSettingsSpy.settings = .fake(bufferSize: 64, sampleRate: 44_100)
        createSut()

        #expect(sut.bufferSize == 64)
        #expect(sut.sampleRate == 44_100)
        #expect(sut.availableBufferSizes == [])
        #expect(sut.availableSampleRates == [])
    }

    @Test
    mutating func projections_followModelState() {
        createSut()
        let device = AudioDevice.fake(id: 1, uid: "in", inputChannels: [.fake(id: 1)])

        audioSettingsSpy.inputDevices = [device]
        audioSettingsSpy.settings = .fake(inputDevice: device, bufferSize: 128)
        audioSettingsSpy.targetDevice = .fake(availableBufferSizes: [128])

        #expect(sut.inputState.devices == [device])
        #expect(sut.inputState.selectedDevice == device)
        #expect(sut.bufferSize == 128)
        #expect(sut.availableBufferSizes == [128])
    }

    // MARK: - device picker

    @Test
    mutating func selectInputDevice_persists() async {
        let device = AudioDevice.fake(id: 1, uid: "new")
        createSut()

        await sut.handleInput(.selectDevice(device))

        #expect(sut.inputState.selectedDevice == device)
        #expect(audioSettingsSpy.calls == [.save(.fake(inputDevice: device))])
    }

    @Test
    mutating func selectInputDevice_clearsSelectedChannel() async {
        let device = AudioDevice.fake(id: 1, uid: "in", inputChannels: [.fake(id: 1)])
        let other = AudioDevice.fake(id: 2, uid: "other")
        audioSettingsSpy.settings = .fake(inputDevice: device, inputChannel: .mono(.fake(id: 1)))
        createSut()

        await sut.handleInput(.selectDevice(other))

        #expect(audioSettingsSpy.calls == [.save(.fake(inputDevice: other))])
    }

    @Test
    mutating func selectInputDevice_sameDevice_noOp() async {
        let device = AudioDevice.fake(id: 1, uid: "in")
        audioSettingsSpy.settings = .fake(inputDevice: device)
        createSut()

        await sut.handleInput(.selectDevice(device))

        #expect(audioSettingsSpy.calls.isEmpty)
    }

    @Test
    mutating func setChannel_addsAndRemoves() async {
        let channel1 = AudioChannel.fake(id: 1, name: "Ch1")
        let channel2 = AudioChannel.fake(id: 2, name: "Ch2")
        let device = AudioDevice.fake(id: 1, uid: "in", inputChannels: [channel1, channel2])
        audioSettingsSpy.settings = .fake(inputDevice: device)
        createSut()

        await sut.handleInput(.setChannel(channel1, isOn: true))
        #expect(sut.inputState.selectedChannel == .mono(channel1))

        await sut.handleInput(.setChannel(channel2, isOn: true))
        #expect(sut.inputState.selectedChannel == .stereo(l: channel1, r: channel2))

        await sut.handleInput(.setChannel(channel1, isOn: false))
        #expect(sut.inputState.selectedChannel == .mono(channel2))
    }

    @Test
    mutating func setChannel_thirdSelectionIgnored() async {
        let channel1 = AudioChannel.fake(id: 1, name: "Ch1")
        let channel2 = AudioChannel.fake(id: 2, name: "Ch2")
        let channel3 = AudioChannel.fake(id: 3, name: "Ch3")
        audioSettingsSpy.settings = .fake(inputDevice: .fake(id: 1, uid: "in", inputChannels: [channel1, channel2, channel3]))
        createSut()

        await sut.handleInput(.setChannel(channel1, isOn: true))
        await sut.handleInput(.setChannel(channel2, isOn: true))
        await sut.handleInput(.setChannel(channel3, isOn: true))

        #expect(sut.inputState.selectedChannel == .stereo(l: channel1, r: channel2))
    }

    @Test
    mutating func selectOutputDevice_persists() async {
        let device = AudioDevice.fake(id: 2, uid: "out")
        createSut()

        await sut.handleOutput(.selectDevice(device))

        #expect(sut.outputState.selectedDevice == device)
        #expect(audioSettingsSpy.calls == [.save(.fake(outputDevice: device))])
    }

    // MARK: - MIDI device picker

    @Test
    mutating func setMidiDeviceOn_persists() async {
        let device = MidiDevice.fake(ref: 10, uid: 100)
        createSut()

        await sut.handleMidi(.setDevice(device, isOn: true))

        #expect(sut.midiState.selectedDevices == [device])
        #expect(audioSettingsSpy.calls == [.save(.fake(selectedMidiDevices: [device]))])
    }

    @Test
    mutating func setMidiDeviceOff_persists() async {
        let device = MidiDevice.fake(ref: 10, uid: 100)
        audioSettingsSpy.settings = .fake(selectedMidiDevices: [device])
        createSut()

        await sut.handleMidi(.setDevice(device, isOn: false))

        #expect(sut.midiState.selectedDevices == [])
        #expect(audioSettingsSpy.calls == [.save(.fake(selectedMidiDevices: []))])
    }

    @Test
    mutating func unrelatedChange_preservesMidiSelection() async {
        let device = MidiDevice.fake(ref: 10, uid: 100)
        audioSettingsSpy.settings = .fake(bufferSize: 32, selectedMidiDevices: [device])
        createSut()

        await sut.selectBufferSize(64)

        #expect(audioSettingsSpy.calls == [.save(.fake(bufferSize: 64, selectedMidiDevices: [device]))])
    }

    // MARK: - buffer / sample rate

    @Test
    mutating func selectBufferSize_changes_persists() async {
        audioSettingsSpy.settings = .fake(bufferSize: 32)
        createSut()

        await sut.selectBufferSize(128)

        #expect(sut.bufferSize == 128)
        #expect(audioSettingsSpy.calls == [.save(.fake(bufferSize: 128))])
    }

    @Test
    mutating func selectBufferSize_sameValue_noOp() async {
        audioSettingsSpy.settings = .fake(bufferSize: 64)
        createSut()

        await sut.selectBufferSize(64)

        #expect(audioSettingsSpy.calls.isEmpty)
    }

    @Test
    mutating func selectSampleRate_changes_persists() async {
        audioSettingsSpy.settings = .fake(sampleRate: 48_000)
        createSut()

        await sut.selectSampleRate(96_000)

        #expect(sut.sampleRate == 96_000)
        #expect(audioSettingsSpy.calls == [.save(.fake(sampleRate: 96_000))])
    }

    @Test
    mutating func selectSampleRate_sameValue_noOp() async {
        audioSettingsSpy.settings = .fake(sampleRate: 48_000)
        createSut()

        await sut.selectSampleRate(48_000)

        #expect(audioSettingsSpy.calls.isEmpty)
    }
}
