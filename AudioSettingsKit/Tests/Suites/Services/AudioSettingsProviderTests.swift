//
//  AudioSettingsProviderTests.swift
//  AudioSettingsKitTests
//
//  Created by Alex Shubin on 04.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioSettingsKitTestSupport
import StorageKit
import StorageKitTestSupport
import Testing
@testable import AudioSettingsKit

@Suite
struct AudioSettingsProviderTests {
    var rawStoreMock: RawSettingsStoreMock!
    var devicesProviderMock: AudioDevicesProviderMock!
    var midiDevicesProviderMock: MidiDevicesProviderMock!
    var sut: AudioSettingsProviderType!

    init() {
        rawStoreMock = RawSettingsStoreMock()
        devicesProviderMock = AudioDevicesProviderMock()
        midiDevicesProviderMock = MidiDevicesProviderMock()
    }

    mutating func createSut() {
        sut = AudioSettingsProvider(
            rawStore: rawStoreMock,
            devicesProvider: devicesProviderMock,
            midiDevicesProvider: midiDevicesProviderMock
        )
    }

    // MARK: - current

    @Test
    mutating func current_emptyRaw_returnsEmpty() async {
        createSut()

        #expect(sut.current == .empty)
    }

    @Test
    mutating func current_passesThroughBufferAndSampleRate() async {
        rawStoreMock.settings = .fake(bufferSize: 256, sampleRate: 48_000)
        createSut()

        let result = sut.current

        #expect(result == .fake(bufferSize: 256, sampleRate: 48_000))
    }

    @Test
    mutating func current_resolvesInputDeviceByUID() async {
        let device = AudioDevice.fake(id: 1, uid: "in-uid")
        devicesProviderMock.devicesResult = [device]
        rawStoreMock.settings = .fake(input: .fake(uid: "in-uid"))
        createSut()

        let result = sut.current

        #expect(result.inputDevice == device)
        #expect(result.outputDevice == nil)
    }

    @Test
    mutating func current_resolvesOutputDeviceByUID() async {
        let device = AudioDevice.fake(id: 2, uid: "out-uid")
        devicesProviderMock.devicesResult = [device]
        rawStoreMock.settings = .fake(output: .fake(uid: "out-uid"))
        createSut()

        let result = sut.current

        #expect(result.outputDevice == device)
        #expect(result.inputDevice == nil)
    }

    @Test
    mutating func current_uidWithoutMatchingDevice_returnsNilDevice() async {
        devicesProviderMock.devicesResult = [.fake(id: 1, uid: "other")]
        rawStoreMock.settings = .fake(input: .fake(uid: "missing"))
        createSut()

        let result = sut.current

        #expect(result.inputDevice == nil)
    }

    @Test
    mutating func current_resolvesMonoInputChannel() async {
        let channel = AudioChannel(id: 1, name: "Channel 1")
        let device = AudioDevice.fake(uid: "in-uid", inputChannels: [channel])
        devicesProviderMock.devicesResult = [device]
        rawStoreMock.settings = .fake(input: .fake(uid: "in-uid", selectedChannels: [1]))
        createSut()

        let result = sut.current

        #expect(result.inputChannel == .mono(channel))
    }

    @Test
    mutating func current_resolvesStereoOutputChannel() async {
        let left = AudioChannel(id: 1, name: "Channel 1")
        let right = AudioChannel(id: 2, name: "Channel 2")
        let device = AudioDevice.fake(uid: "out-uid", outputChannels: [left, right])
        devicesProviderMock.devicesResult = [device]
        rawStoreMock.settings = .fake(output: .fake(uid: "out-uid", selectedChannels: [1, 2]))
        createSut()

        let result = sut.current

        #expect(result.outputChannel == .stereo(l: left, r: right))
    }

    @Test
    mutating func current_channelIDsMissingFromDevice_returnsNilChannel() async {
        let channel = AudioChannel(id: 1, name: "Channel 1")
        let device = AudioDevice.fake(uid: "in-uid", inputChannels: [channel])
        devicesProviderMock.devicesResult = [device]
        rawStoreMock.settings = .fake(input: .fake(uid: "in-uid", selectedChannels: [99]))
        createSut()

        let result = sut.current

        #expect(result.inputChannel == nil)
    }

    @Test
    mutating func current_deviceMissing_returnsNilChannelEvenWithSelectedIDs() async {
        rawStoreMock.settings = .fake(input: .fake(uid: "missing", selectedChannels: [1, 2]))
        createSut()

        let result = sut.current

        #expect(result.inputDevice == nil)
        #expect(result.inputChannel == nil)
    }

    @Test
    mutating func current_requestsAllDevicesAndReadsRawStore() async {
        createSut()

        _ = sut.current

        #expect(devicesProviderMock.calls == [.devices(.all)])
        #expect(midiDevicesProviderMock.calls == [.devices])
        #expect(rawStoreMock.calls == [.current])
    }

    // MARK: - MIDI

    @Test
    mutating func current_resolvesSelectedMidiDevicesByUID() async {
        let selected = MidiDevice.fake(ref: 10, uid: 100, name: "Keystep")
        midiDevicesProviderMock.devicesResult = [selected, .fake(ref: 20, uid: 200, name: "Push")]
        rawStoreMock.settings = .fake(selectedMidiUIDs: [100])
        createSut()

        #expect(sut.current.selectedMidiDevices == [selected])
    }

    @Test
    mutating func current_selectedMidiUIDWithoutLiveSource_isExcluded() async {
        midiDevicesProviderMock.devicesResult = [.fake(ref: 10, uid: 100)]
        rawStoreMock.settings = .fake(selectedMidiUIDs: [999])
        createSut()

        #expect(sut.current.selectedMidiDevices.isEmpty)
    }

    @Test
    mutating func save_persistsSelectedMidiUIDsSorted() {
        createSut()

        sut.save(.fake(selectedMidiDevices: [.fake(uid: 200), .fake(uid: 100)]))

        #expect(rawStoreMock.settings.selectedMidiUIDs == [100, 200])
    }

    // MARK: - save

    @Test
    mutating func save_persistsDeviceUIDs() {
        let inDevice = AudioDevice.fake(id: 1, uid: "in-uid")
        let outDevice = AudioDevice.fake(id: 2, uid: "out-uid")
        createSut()

        sut.save(.fake(inputDevice: inDevice, outputDevice: outDevice))

        let raw = rawStoreMock.settings
        #expect(raw.input?.uid == "in-uid")
        #expect(raw.output?.uid == "out-uid")
    }

    @Test
    mutating func save_nilDevice_persistsNilEntry() {
        createSut()

        sut.save(.empty)

        let raw = rawStoreMock.settings
        #expect(raw.input == nil)
        #expect(raw.output == nil)
    }

    @Test
    mutating func save_persistsMonoChannelID() {
        let channel = AudioChannel(id: 7, name: "Channel 7")
        let device = AudioDevice.fake(uid: "in-uid", inputChannels: [channel])
        createSut()

        sut.save(.fake(inputDevice: device, inputChannel: .mono(channel)))

        let raw = rawStoreMock.settings
        #expect(raw.input?.selectedChannels == [7])
    }

    @Test
    mutating func save_persistsStereoChannelIDs() {
        let left = AudioChannel(id: 1, name: "Channel 1")
        let right = AudioChannel(id: 2, name: "Channel 2")
        let device = AudioDevice.fake(uid: "out-uid", outputChannels: [left, right])
        createSut()

        sut.save(.fake(outputDevice: device, outputChannel: .stereo(l: left, r: right)))

        let raw = rawStoreMock.settings
        #expect(raw.output?.selectedChannels == [1, 2])
    }

    @Test
    mutating func save_persistsBufferAndSampleRate() {
        createSut()

        sut.save(.fake(bufferSize: 512, sampleRate: 96_000))

        let raw = rawStoreMock.settings
        #expect(raw.bufferSize == 512)
        #expect(raw.sampleRate == 96_000)
    }
}
