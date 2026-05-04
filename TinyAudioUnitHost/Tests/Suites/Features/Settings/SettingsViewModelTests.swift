//
//  SettingsViewModelTests.swift
//  TinyAudioUnitHostTests
//
//  Created by Alex Shubin on 04.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioSettingsKit
import AudioSettingsKitTestSupport
import EngineKitTestSupport
import Testing
@testable import TinyAudioUnitHost

@MainActor
@Suite
struct SettingsViewModelTests {
    var audioSettingsMock: AudioSettingsProviderMock!
    var targetSettingsMock: TargetSettingsProviderMock!
    var devicesProviderMock: AudioDevicesProviderMock!
    var engineMock: EngineMock!
    var sut: SettingsViewModelType!

    init() {
        audioSettingsMock = AudioSettingsProviderMock()
        targetSettingsMock = TargetSettingsProviderMock()
        devicesProviderMock = AudioDevicesProviderMock()
        engineMock = EngineMock()
    }

    mutating func createSut() {
        sut = SettingsViewModel(
            audioSettings: audioSettingsMock,
            targetSettings: targetSettingsMock,
            devicesProvider: devicesProviderMock,
            engine: engineMock
        )
    }

    // MARK: - task

    @Test
    mutating func task_populatesPickerStatesFromSettingsAndDevices() async {
        let inDevice = AudioDevice.fake(id: 1, uid: "in", inputChannels: [.fake(id: 1)])
        let outDevice = AudioDevice.fake(id: 2, uid: "out", outputChannels: [.fake(id: 1)])
        devicesProviderMock.devicesResult = [inDevice, outDevice]
        await audioSettingsMock.setSettings(.fake(
            inputDevice: inDevice,
            outputDevice: outDevice,
            inputChannel: .mono(.fake(id: 1)),
            outputChannel: .mono(.fake(id: 1))
        ))
        createSut()

        await sut.accept(action: .task)

        #expect(sut.inputState.devices == [inDevice, outDevice])
        #expect(sut.inputState.selectedDevice == inDevice)
        #expect(sut.inputState.selectedChannel == .mono(.fake(id: 1)))
        #expect(sut.outputState.selectedDevice == outDevice)
        #expect(sut.outputState.selectedChannel == .mono(.fake(id: 1)))
    }

    @Test
    mutating func task_setsBufferAndSampleRateFromTarget() async {
        let device = AudioDevice.fake(
            availableBufferSizes: [32, 64, 128],
            availableSampleRates: [44_100, 48_000]
        )
        await audioSettingsMock.setSettings(.fake(bufferSize: 64, sampleRate: 44_100))
        await targetSettingsMock.setResolveTargetResult(.fake(device: device))
        createSut()

        await sut.accept(action: .task)

        #expect(sut.bufferSize == 64)
        #expect(sut.availableBufferSizes == [32, 64, 128])
        #expect(sut.sampleRate == 44_100)
        #expect(sut.availableSampleRates == [44_100, 48_000])
    }

    @Test
    mutating func task_resolvesInvalidBufferSizeTo32() async {
        let device = AudioDevice.fake(availableBufferSizes: [32, 64])
        await audioSettingsMock.setSettings(.fake(bufferSize: 9999))
        await targetSettingsMock.setResolveTargetResult(.fake(device: device))
        createSut()

        await sut.accept(action: .task)

        #expect(sut.bufferSize == 32)
    }

    @Test
    mutating func task_resolvesInvalidSampleRateTo48000() async {
        let device = AudioDevice.fake(availableSampleRates: [44_100, 48_000])
        await audioSettingsMock.setSettings(.fake(sampleRate: 9999))
        await targetSettingsMock.setResolveTargetResult(.fake(device: device))
        createSut()

        await sut.accept(action: .task)

        #expect(sut.sampleRate == 48_000)
    }

    @Test
    mutating func task_fallsBackToFirstAvailableWhenDefaultsAbsent() async {
        let device = AudioDevice.fake(
            availableBufferSizes: [256, 512],
            availableSampleRates: [88_200, 96_000]
        )
        await audioSettingsMock.setSettings(.fake(bufferSize: 9999, sampleRate: 9999))
        await targetSettingsMock.setResolveTargetResult(.fake(device: device))
        createSut()

        await sut.accept(action: .task)

        #expect(sut.bufferSize == 256)
        #expect(sut.sampleRate == 88_200)
    }

    @Test
    mutating func task_noTarget_clearsAvailableAndResolvesNil() async {
        await audioSettingsMock.setSettings(.fake(bufferSize: 64, sampleRate: 44_100))
        createSut()

        await sut.accept(action: .task)

        #expect(sut.bufferSize == nil)
        #expect(sut.sampleRate == nil)
        #expect(sut.availableBufferSizes == [])
        #expect(sut.availableSampleRates == [])
    }

    @Test
    mutating func task_persistsResolvedBufferSize_whenChanged() async {
        let device = AudioDevice.fake(availableBufferSizes: [32, 64])
        await audioSettingsMock.setSettings(.fake(bufferSize: 9999))
        await targetSettingsMock.setResolveTargetResult(.fake(device: device))
        createSut()

        await sut.accept(action: .task)

        #expect(await audioSettingsMock.settings.bufferSize == 32)
    }

    @Test
    mutating func task_callsEngineReload() async {
        createSut()

        await sut.accept(action: .task)

        #expect(await engineMock.calls == [.reload])
    }

    // MARK: - device picker

    @Test
    mutating func selectInputDevice_persistsAndCallsReload() async {
        let device = AudioDevice.fake(id: 1, uid: "new")
        devicesProviderMock.devicesResult = [device]
        createSut()
        await sut.accept(action: .task)

        await sut.accept(action: .inputDevicePickerAction(.selectDevice(device)))

        #expect(sut.inputState.selectedDevice == device)
        #expect(await audioSettingsMock.settings.inputDevice == device)
        #expect(await engineMock.calls == [.reload, .reload])
    }

    @Test
    mutating func selectInputDevice_clearsSelectedChannel() async {
        let device = AudioDevice.fake(id: 1, uid: "in", inputChannels: [.fake(id: 1)])
        let other = AudioDevice.fake(id: 2, uid: "other")
        devicesProviderMock.devicesResult = [device, other]
        await audioSettingsMock.setSettings(.fake(
            inputDevice: device,
            inputChannel: .mono(.fake(id: 1))
        ))
        createSut()
        await sut.accept(action: .task)

        await sut.accept(action: .inputDevicePickerAction(.selectDevice(other)))

        #expect(sut.inputState.selectedDevice == other)
        #expect(sut.inputState.selectedChannel == nil)
    }

    @Test
    mutating func selectInputDevice_sameDevice_noOp() async {
        let device = AudioDevice.fake(id: 1, uid: "in")
        devicesProviderMock.devicesResult = [device]
        await audioSettingsMock.setSettings(.fake(inputDevice: device))
        createSut()
        await sut.accept(action: .task)
        let updateCallsBefore = await audioSettingsMock.calls.filter { $0 == .update }.count
        let reloadCallsBefore = await engineMock.calls.count

        await sut.accept(action: .inputDevicePickerAction(.selectDevice(device)))

        #expect(await audioSettingsMock.calls.filter { $0 == .update }.count == updateCallsBefore)
        #expect(await engineMock.calls.count == reloadCallsBefore)
    }

    @Test
    mutating func setChannel_addsAndRemoves() async {
        let channel1 = AudioChannel.fake(id: 1, name: "Ch1")
        let channel2 = AudioChannel.fake(id: 2, name: "Ch2")
        let device = AudioDevice.fake(id: 1, uid: "in", inputChannels: [channel1, channel2])
        devicesProviderMock.devicesResult = [device]
        await audioSettingsMock.setSettings(.fake(inputDevice: device))
        createSut()
        await sut.accept(action: .task)

        await sut.accept(action: .inputDevicePickerAction(.setChannel(channel1, isOn: true)))
        #expect(sut.inputState.selectedChannel == .mono(channel1))

        await sut.accept(action: .inputDevicePickerAction(.setChannel(channel2, isOn: true)))
        #expect(sut.inputState.selectedChannel == .stereo(l: channel1, r: channel2))

        await sut.accept(action: .inputDevicePickerAction(.setChannel(channel1, isOn: false)))
        #expect(sut.inputState.selectedChannel == .mono(channel2))
    }

    @Test
    mutating func setChannel_thirdSelectionIgnored() async {
        let channel1 = AudioChannel.fake(id: 1, name: "Ch1")
        let channel2 = AudioChannel.fake(id: 2, name: "Ch2")
        let channel3 = AudioChannel.fake(id: 3, name: "Ch3")
        let device = AudioDevice.fake(id: 1, uid: "in", inputChannels: [channel1, channel2, channel3])
        devicesProviderMock.devicesResult = [device]
        await audioSettingsMock.setSettings(.fake(inputDevice: device))
        createSut()
        await sut.accept(action: .task)

        await sut.accept(action: .inputDevicePickerAction(.setChannel(channel1, isOn: true)))
        await sut.accept(action: .inputDevicePickerAction(.setChannel(channel2, isOn: true)))
        await sut.accept(action: .inputDevicePickerAction(.setChannel(channel3, isOn: true)))

        #expect(sut.inputState.selectedChannel == .stereo(l: channel1, r: channel2))
    }

    @Test
    mutating func selectOutputDevice_persistsAndCallsReload() async {
        let device = AudioDevice.fake(id: 2, uid: "out")
        devicesProviderMock.devicesResult = [device]
        createSut()
        await sut.accept(action: .task)

        await sut.accept(action: .outputDevicePickerAction(.selectDevice(device)))

        #expect(sut.outputState.selectedDevice == device)
        #expect(await audioSettingsMock.settings.outputDevice == device)
    }

    // MARK: - buffer / sample rate

    @Test
    mutating func selectBufferSize_changes_persistsAndReloads() async {
        let device = AudioDevice.fake(availableBufferSizes: [32, 64, 128])
        await audioSettingsMock.setSettings(.fake(bufferSize: 32))
        await targetSettingsMock.setResolveTargetResult(.fake(device: device))
        createSut()
        await sut.accept(action: .task)

        await sut.accept(action: .selectBufferSize(128))

        #expect(sut.bufferSize == 128)
        #expect(await audioSettingsMock.settings.bufferSize == 128)
        #expect(await engineMock.calls == [.reload, .reload])
    }

    @Test
    mutating func selectBufferSize_sameValue_noOp() async {
        let device = AudioDevice.fake(availableBufferSizes: [32, 64])
        await audioSettingsMock.setSettings(.fake(bufferSize: 64))
        await targetSettingsMock.setResolveTargetResult(.fake(device: device))
        createSut()
        await sut.accept(action: .task)
        let reloadsBefore = await engineMock.calls.count

        await sut.accept(action: .selectBufferSize(64))

        #expect(await engineMock.calls.count == reloadsBefore)
    }

    @Test
    mutating func selectSampleRate_changes_persistsAndReloads() async {
        let device = AudioDevice.fake(availableSampleRates: [44_100, 48_000, 96_000])
        await audioSettingsMock.setSettings(.fake(sampleRate: 48_000))
        await targetSettingsMock.setResolveTargetResult(.fake(device: device))
        createSut()
        await sut.accept(action: .task)

        await sut.accept(action: .selectSampleRate(96_000))

        #expect(sut.sampleRate == 96_000)
        #expect(await audioSettingsMock.settings.sampleRate == 96_000)
    }

    @Test
    mutating func selectSampleRate_sameValue_noOp() async {
        let device = AudioDevice.fake(availableSampleRates: [44_100, 48_000])
        await audioSettingsMock.setSettings(.fake(sampleRate: 48_000))
        await targetSettingsMock.setResolveTargetResult(.fake(device: device))
        createSut()
        await sut.accept(action: .task)
        let reloadsBefore = await engineMock.calls.count

        await sut.accept(action: .selectSampleRate(48_000))

        #expect(await engineMock.calls.count == reloadsBefore)
    }
}
