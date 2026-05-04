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
    var sut: AudioSettingsProviderType!

    init() {
        rawStoreMock = RawSettingsStoreMock()
        devicesProviderMock = AudioDevicesProviderMock()
    }

    mutating func createSut() {
        sut = AudioSettingsProvider(
            rawStore: rawStoreMock,
            devicesProvider: devicesProviderMock
        )
    }

    // MARK: - current

    @Test
    mutating func current_emptyRaw_returnsEmpty() async {
        createSut()

        #expect(await sut.current() == .empty)
    }

    @Test
    mutating func current_passesThroughBufferAndSampleRate() async {
        await rawStoreMock.setSettings(.fake(bufferSize: 256, sampleRate: 48_000))
        createSut()

        let result = await sut.current()

        #expect(result == .fake(bufferSize: 256, sampleRate: 48_000))
    }

    @Test
    mutating func current_resolvesInputDeviceByUID() async {
        let device = AudioDevice.fake(id: 1, uid: "in-uid")
        devicesProviderMock.devicesResult = [device]
        await rawStoreMock.setSettings(.fake(input: .fake(uid: "in-uid")))
        createSut()

        let result = await sut.current()

        #expect(result.inputDevice == device)
        #expect(result.outputDevice == nil)
    }

    @Test
    mutating func current_resolvesOutputDeviceByUID() async {
        let device = AudioDevice.fake(id: 2, uid: "out-uid")
        devicesProviderMock.devicesResult = [device]
        await rawStoreMock.setSettings(.fake(output: .fake(uid: "out-uid")))
        createSut()

        let result = await sut.current()

        #expect(result.outputDevice == device)
        #expect(result.inputDevice == nil)
    }

    @Test
    mutating func current_uidWithoutMatchingDevice_returnsNilDevice() async {
        devicesProviderMock.devicesResult = [.fake(id: 1, uid: "other")]
        await rawStoreMock.setSettings(.fake(input: .fake(uid: "missing")))
        createSut()

        let result = await sut.current()

        #expect(result.inputDevice == nil)
    }

    @Test
    mutating func current_resolvesMonoInputChannel() async {
        let channel = AudioChannel(id: 1, name: "Channel 1")
        let device = AudioDevice.fake(uid: "in-uid", inputChannels: [channel])
        devicesProviderMock.devicesResult = [device]
        await rawStoreMock.setSettings(.fake(input: .fake(uid: "in-uid", selectedChannels: [1])))
        createSut()

        let result = await sut.current()

        #expect(result.inputChannel == .mono(channel))
    }

    @Test
    mutating func current_resolvesStereoOutputChannel() async {
        let left = AudioChannel(id: 1, name: "Channel 1")
        let right = AudioChannel(id: 2, name: "Channel 2")
        let device = AudioDevice.fake(uid: "out-uid", outputChannels: [left, right])
        devicesProviderMock.devicesResult = [device]
        await rawStoreMock.setSettings(.fake(output: .fake(uid: "out-uid", selectedChannels: [1, 2])))
        createSut()

        let result = await sut.current()

        #expect(result.outputChannel == .stereo(l: left, r: right))
    }

    @Test
    mutating func current_channelIDsMissingFromDevice_returnsNilChannel() async {
        let channel = AudioChannel(id: 1, name: "Channel 1")
        let device = AudioDevice.fake(uid: "in-uid", inputChannels: [channel])
        devicesProviderMock.devicesResult = [device]
        await rawStoreMock.setSettings(.fake(input: .fake(uid: "in-uid", selectedChannels: [99])))
        createSut()

        let result = await sut.current()

        #expect(result.inputChannel == nil)
    }

    @Test
    mutating func current_deviceMissing_returnsNilChannelEvenWithSelectedIDs() async {
        await rawStoreMock.setSettings(.fake(input: .fake(uid: "missing", selectedChannels: [1, 2])))
        createSut()

        let result = await sut.current()

        #expect(result.inputDevice == nil)
        #expect(result.inputChannel == nil)
    }

    @Test
    mutating func current_requestsAllDevicesAndReadsRawStore() async {
        createSut()

        _ = await sut.current()

        #expect(devicesProviderMock.calls == [.devices(.all)])
        #expect(await rawStoreMock.calls == [.current])
    }

    // MARK: - update

    @Test
    mutating func update_persistsTransformedDeviceUIDs() async {
        let inDevice = AudioDevice.fake(id: 1, uid: "in-uid")
        let outDevice = AudioDevice.fake(id: 2, uid: "out-uid")
        devicesProviderMock.devicesResult = [inDevice, outDevice]
        createSut()

        await sut.update { settings in
            settings.inputDevice = inDevice
            settings.outputDevice = outDevice
        }

        let raw = await rawStoreMock.settings
        #expect(raw.input.uid == "in-uid")
        #expect(raw.output.uid == "out-uid")
    }

    @Test
    mutating func update_clearingDevice_persistsNilUIDAndEmptyChannels() async {
        let device = AudioDevice.fake(uid: "in-uid", inputChannels: [.init(id: 1, name: "Channel 1")])
        devicesProviderMock.devicesResult = [device]
        await rawStoreMock.setSettings(.fake(input: .fake(uid: "in-uid", selectedChannels: [1])))
        createSut()

        await sut.update { settings in
            settings.inputDevice = nil
            settings.inputChannel = nil
        }

        let raw = await rawStoreMock.settings
        #expect(raw.input.uid == nil)
        #expect(raw.input.selectedChannels == [])
    }

    @Test
    mutating func update_persistsMonoChannelID() async {
        let channel = AudioChannel(id: 7, name: "Channel 7")
        createSut()

        await sut.update { $0.inputChannel = .mono(channel) }

        let raw = await rawStoreMock.settings
        #expect(raw.input.selectedChannels == [7])
    }

    @Test
    mutating func update_persistsStereoChannelIDs() async {
        let left = AudioChannel(id: 1, name: "Channel 1")
        let right = AudioChannel(id: 2, name: "Channel 2")
        createSut()

        await sut.update { $0.outputChannel = .stereo(l: left, r: right) }

        let raw = await rawStoreMock.settings
        #expect(raw.output.selectedChannels == [1, 2])
    }

    @Test
    mutating func update_persistsBufferAndSampleRate() async {
        createSut()

        await sut.update { settings in
            settings.bufferSize = 512
            settings.sampleRate = 96_000
        }

        let raw = await rawStoreMock.settings
        #expect(raw.bufferSize == 512)
        #expect(raw.sampleRate == 96_000)
    }

    @Test
    mutating func update_readsCurrentBeforePersisting() async {
        createSut()

        await sut.update { _ in }

        #expect(await rawStoreMock.calls == [.current, .update])
    }

    @Test
    mutating func update_resolvesExistingSettings_thenAppliesTransform() async {
        let device = AudioDevice.fake(id: 1, uid: "in-uid", inputChannels: [.init(id: 1, name: "Channel 1")])
        devicesProviderMock.devicesResult = [device]
        await rawStoreMock.setSettings(.fake(
            input: .fake(uid: "in-uid", selectedChannels: [1]),
            bufferSize: 128
        ))
        createSut()

        await sut.update { settings in
            settings.bufferSize = 256
        }

        let raw = await rawStoreMock.settings
        #expect(raw.input.uid == "in-uid")
        #expect(raw.input.selectedChannels == [1])
        #expect(raw.bufferSize == 256)
    }
}
