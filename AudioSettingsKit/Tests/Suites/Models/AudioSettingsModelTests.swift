//
//  AudioSettingsModelTests.swift
//  AudioSettingsKitTests
//
//  Created by Alex Shubin on 08.10.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioSettingsKitTestSupport
import CoreAudioGatewayKitTestSupport
import StorageKit
import StorageKitTestSupport
import Testing
@testable import AudioSettingsKit

@Suite @MainActor
struct AudioSettingsModelTests {
    var rawStoreSpy: RawSettingsStoreSpy!
    var devicesProviderSpy: AudioDevicesProviderSpy!
    var midiDevicesProviderSpy: MidiDevicesProviderSpy!
    var targetResolverSpy: TargetDeviceResolverSpy!
    var deviceConfiguratorSpy: AudioDeviceConfiguratorSpy!
    var coreAudioGatewaySpy: CoreAudioGatewaySpy!
    var midiSetupListenerSpy: MidiSetupChangeListenerSpy!
    var delegateSpy: AudioSettingsModelDelegateSpy!
    var sut: AudioSettingsModelType!

    init() {
        rawStoreSpy = RawSettingsStoreSpy()
        devicesProviderSpy = AudioDevicesProviderSpy()
        midiDevicesProviderSpy = MidiDevicesProviderSpy()
        targetResolverSpy = TargetDeviceResolverSpy()
        deviceConfiguratorSpy = AudioDeviceConfiguratorSpy()
        coreAudioGatewaySpy = CoreAudioGatewaySpy()
        midiSetupListenerSpy = MidiSetupChangeListenerSpy()
        delegateSpy = AudioSettingsModelDelegateSpy()
    }

    mutating func createSut() {
        sut = AudioSettingsModel(
            rawStore: rawStoreSpy,
            devicesProvider: devicesProviderSpy,
            midiDevicesProvider: midiDevicesProviderSpy,
            targetResolver: targetResolverSpy,
            deviceConfigurator: deviceConfiguratorSpy,
            coreAudioGateway: coreAudioGatewaySpy,
            midiSetupChangeListener: midiSetupListenerSpy
        )
        sut.delegate = delegateSpy
    }

    // MARK: - init

    @Test
    mutating func init_observesDeviceListChanges() async {
        createSut()

        #expect(coreAudioGatewaySpy.calls == [.observeDeviceListChanges])
    }

    @Test
    mutating func init_observesMidiSetupChanges() async {
        createSut()

        #expect(midiSetupListenerSpy.calls == [.observeChanges])
    }

    @Test
    mutating func init_startsEmptyWithoutTarget() async {
        createSut()

        #expect(sut.settings == .empty)
        #expect(sut.targetDevice == nil)
        #expect(rawStoreSpy.calls.isEmpty)
    }

    // MARK: - load

    @Test
    mutating func load_emptyRaw_settingsStayEmpty() async {
        createSut()

        await sut.load()

        #expect(sut.settings == .empty)
    }

    @Test
    mutating func load_passesThroughBufferAndSampleRate() async {
        rawStoreSpy.settings = .fake(bufferSize: 256, sampleRate: 48_000)
        createSut()

        await sut.load()

        #expect(sut.settings == .fake(bufferSize: 256, sampleRate: 48_000))
    }

    @Test
    mutating func load_resolvesInputDeviceByUID() async {
        let device = AudioDevice.fake(id: 1, uid: "in-uid")
        devicesProviderSpy.scanDevicesResult = [device]
        rawStoreSpy.settings = .fake(input: .fake(uid: "in-uid"))
        createSut()

        await sut.load()

        #expect(sut.settings.inputDevice == device)
        #expect(sut.settings.outputDevice == nil)
    }

    @Test
    mutating func load_resolvesOutputDeviceByUID() async {
        let device = AudioDevice.fake(id: 2, uid: "out-uid")
        devicesProviderSpy.scanDevicesResult = [device]
        rawStoreSpy.settings = .fake(output: .fake(uid: "out-uid"))
        createSut()

        await sut.load()

        #expect(sut.settings.outputDevice == device)
        #expect(sut.settings.inputDevice == nil)
    }

    @Test
    mutating func load_uidWithoutMatchingDevice_leavesDeviceNil() async {
        devicesProviderSpy.scanDevicesResult = [.fake(id: 1, uid: "other")]
        rawStoreSpy.settings = .fake(input: .fake(uid: "missing"))
        createSut()

        await sut.load()

        #expect(sut.settings.inputDevice == nil)
    }

    @Test
    mutating func load_resolvesMonoInputChannel() async {
        let channel = AudioChannel(id: 1, name: "Channel 1")
        devicesProviderSpy.scanDevicesResult = [.fake(uid: "in-uid", inputChannels: [channel])]
        rawStoreSpy.settings = .fake(input: .fake(uid: "in-uid", selectedChannels: [1]))
        createSut()

        await sut.load()

        #expect(sut.settings.inputChannel == .mono(channel))
    }

    @Test
    mutating func load_resolvesStereoOutputChannel() async {
        let left = AudioChannel(id: 1, name: "Channel 1")
        let right = AudioChannel(id: 2, name: "Channel 2")
        devicesProviderSpy.scanDevicesResult = [.fake(uid: "out-uid", outputChannels: [left, right])]
        rawStoreSpy.settings = .fake(output: .fake(uid: "out-uid", selectedChannels: [1, 2]))
        createSut()

        await sut.load()

        #expect(sut.settings.outputChannel == .stereo(l: left, r: right))
    }

    @Test
    mutating func load_channelIDsMissingFromDevice_leavesChannelNil() async {
        devicesProviderSpy.scanDevicesResult = [.fake(uid: "in-uid", inputChannels: [AudioChannel(id: 1, name: "Channel 1")])]
        rawStoreSpy.settings = .fake(input: .fake(uid: "in-uid", selectedChannels: [99]))
        createSut()

        await sut.load()

        #expect(sut.settings.inputChannel == nil)
    }

    @Test
    mutating func load_deviceMissing_leavesChannelNilEvenWithSelectedIDs() async {
        rawStoreSpy.settings = .fake(input: .fake(uid: "missing", selectedChannels: [1, 2]))
        createSut()

        await sut.load()

        #expect(sut.settings.inputDevice == nil)
        #expect(sut.settings.inputChannel == nil)
    }

    @Test
    mutating func load_requestsAllDevicesAndReadsRawStore() async {
        createSut()

        await sut.load()

        #expect(devicesProviderSpy.calls == [.scanDevices])
        #expect(midiDevicesProviderSpy.calls == [.devices])
        #expect(rawStoreSpy.calls == [.current])
    }

    @Test
    mutating func load_resolvesSelectedMidiDevicesByUID() async {
        let selected = MidiDevice.fake(ref: 10, uid: 100, name: "Keystep")
        midiDevicesProviderSpy.devicesResult = [selected, .fake(ref: 20, uid: 200, name: "Push")]
        rawStoreSpy.settings = .fake(selectedMidiUIDs: [100])
        createSut()

        await sut.load()

        #expect(sut.settings.selectedMidiDevices == [selected])
    }

    @Test
    mutating func load_selectedMidiUIDWithoutLiveSource_isExcluded() async {
        midiDevicesProviderSpy.devicesResult = [.fake(ref: 10, uid: 100)]
        rawStoreSpy.settings = .fake(selectedMidiUIDs: [999])
        createSut()

        await sut.load()

        #expect(sut.settings.selectedMidiDevices.isEmpty)
    }

    @Test
    mutating func load_resolvesTargetDeviceFromLoadedSettings() async {
        let output = AudioDevice.fake(id: 2, uid: "out-uid")
        devicesProviderSpy.scanDevicesResult = [output]
        rawStoreSpy.settings = .fake(output: .fake(uid: "out-uid"))
        targetResolverSpy.resolveResult = output
        createSut()

        await sut.load()

        #expect(sut.targetDevice == output)
        #expect(targetResolverSpy.calls == [.resolve(sut.settings)])
    }

    @Test
    mutating func load_configuresTargetDevice() async {
        let output = AudioDevice.fake(id: 2, uid: "out-uid")
        devicesProviderSpy.scanDevicesResult = [output]
        rawStoreSpy.settings = .fake(output: .fake(uid: "out-uid"))
        targetResolverSpy.resolveResult = output
        createSut()

        await sut.load()

        #expect(deviceConfiguratorSpy.calls == [.apply(sut.settings, output)])
    }

    @Test
    mutating func load_withoutTarget_configuresNothing() async {
        createSut()

        await sut.load()

        #expect(deviceConfiguratorSpy.calls.isEmpty)
    }

    // MARK: - save

    @Test
    mutating func save_persistsSelectedMidiUIDsSorted() async {
        createSut()

        await sut.save(.fake(selectedMidiDevices: [.fake(uid: 200), .fake(uid: 100)]))

        #expect(rawStoreSpy.settings.selectedMidiUIDs == [100, 200])
    }

    @Test
    mutating func save_persistsDeviceUIDs() async {
        createSut()

        await sut.save(.fake(inputDevice: .fake(id: 1, uid: "in-uid"), outputDevice: .fake(id: 2, uid: "out-uid")))

        #expect(rawStoreSpy.settings.input?.uid == "in-uid")
        #expect(rawStoreSpy.settings.output?.uid == "out-uid")
    }

    @Test
    mutating func save_nilDevice_persistsNilEntry() async {
        createSut()

        await sut.save(.empty)

        #expect(rawStoreSpy.settings.input == nil)
        #expect(rawStoreSpy.settings.output == nil)
    }

    @Test
    mutating func save_persistsMonoChannelID() async {
        let channel = AudioChannel(id: 7, name: "Channel 7")
        createSut()

        await sut.save(.fake(inputDevice: .fake(uid: "in-uid", inputChannels: [channel]), inputChannel: .mono(channel)))

        #expect(rawStoreSpy.settings.input?.selectedChannels == [7])
    }

    @Test
    mutating func save_persistsStereoChannelIDs() async {
        let left = AudioChannel(id: 1, name: "Channel 1")
        let right = AudioChannel(id: 2, name: "Channel 2")
        createSut()

        await sut.save(.fake(outputDevice: .fake(uid: "out-uid", outputChannels: [left, right]), outputChannel: .stereo(l: left, r: right)))

        #expect(rawStoreSpy.settings.output?.selectedChannels == [1, 2])
    }

    @Test
    mutating func save_persistsBufferAndSampleRate() async {
        createSut()

        await sut.save(.fake(bufferSize: 512, sampleRate: 96_000))

        #expect(rawStoreSpy.settings.bufferSize == 512)
        #expect(rawStoreSpy.settings.sampleRate == 96_000)
    }

    @Test
    mutating func save_appliesSettingsAndTargetWithoutRescanning() async {
        let output = AudioDevice.fake(id: 2, uid: "out-uid")
        devicesProviderSpy.scanDevicesResult = [output]
        createSut()
        await sut.load()
        targetResolverSpy.resolveResult = output

        await sut.save(.fake(outputDevice: output))

        #expect(sut.settings.outputDevice == output)
        #expect(sut.targetDevice == output)
        #expect(rawStoreSpy.calls == [.current, .save(rawStoreSpy.settings)])
        #expect(devicesProviderSpy.calls == [.scanDevices])
    }

    @Test
    mutating func save_withChangedTarget_configuresIt() async {
        let output = AudioDevice.fake(id: 2, uid: "out-uid")
        devicesProviderSpy.scanDevicesResult = [output]
        createSut()
        await sut.load()
        targetResolverSpy.resolveResult = output

        await sut.save(.fake(outputDevice: output))

        #expect(deviceConfiguratorSpy.calls == [.apply(sut.settings, output)])
    }

    // MARK: - device lists

    @Test
    mutating func load_exposesPickerDeviceLists() async {
        let input = AudioDevice.fake(id: 1, uid: "in", inputChannels: [.fake()])
        let output = AudioDevice.fake(id: 2, uid: "out", outputChannels: [.fake()])
        let both = AudioDevice.fake(id: 3, uid: "both", inputChannels: [.fake()], outputChannels: [.fake()])
        let none = AudioDevice.fake(id: 4, uid: "none")
        devicesProviderSpy.scanDevicesResult = [input, output, both, none]
        createSut()

        await sut.load()

        #expect(sut.inputDevices == [input, both])
        #expect(sut.outputDevices == [output, both])
    }

    @Test
    mutating func load_hidesAggregateDevicesFromPickers() async {
        let system = AudioDevice.fake(id: 1, uid: "CADefaultDeviceAggregate-1", inputChannels: [.fake()], outputChannels: [.fake()])
        let own = AudioDevice.fake(id: 2, uid: AggregateDeviceFactory.uidPrefix + "x", inputChannels: [.fake()], outputChannels: [.fake()])
        devicesProviderSpy.scanDevicesResult = [system, own]
        createSut()

        await sut.load()

        #expect(sut.inputDevices.isEmpty)
        #expect(sut.outputDevices.isEmpty)
    }

    @Test
    mutating func load_exposesMidiDevices() async {
        let devices: [MidiDevice] = [.fake(ref: 10, uid: 100), .fake(ref: 20, uid: 200)]
        midiDevicesProviderSpy.devicesResult = devices
        createSut()

        await sut.load()

        #expect(sut.midiDevices == devices)
    }

    @Test
    mutating func save_refreshesMidiDevices() async {
        createSut()
        let device = MidiDevice.fake(ref: 10, uid: 100)
        midiDevicesProviderSpy.devicesResult = [device]

        await sut.save(.empty)

        #expect(sut.midiDevices == [device])
    }

    // MARK: - defaulting

    @Test
    mutating func load_keepsSupportedSampleRateAndBufferSize() async {
        rawStoreSpy.settings = .fake(bufferSize: 128, sampleRate: 96_000)
        targetResolverSpy.resolveResult = .fake(availableBufferSizes: [32, 128], availableSampleRates: [48_000, 96_000])
        createSut()

        await sut.load()

        #expect(sut.settings.bufferSize == 128)
        #expect(sut.settings.sampleRate == 96_000)
    }

    @Test
    mutating func load_defaultsUnsupportedValuesToPreferred() async {
        rawStoreSpy.settings = .fake(bufferSize: 9999, sampleRate: 9999)
        targetResolverSpy.resolveResult = .fake(availableBufferSizes: [32, 64], availableSampleRates: [44_100, 48_000])
        createSut()

        await sut.load()

        #expect(sut.settings.bufferSize == 32)
        #expect(sut.settings.sampleRate == 48_000)
    }

    @Test
    mutating func load_fallsBackToFirstAvailableWhenPreferredAbsent() async {
        rawStoreSpy.settings = .fake(bufferSize: 9999, sampleRate: 9999)
        targetResolverSpy.resolveResult = .fake(availableBufferSizes: [256, 512], availableSampleRates: [88_200, 96_000])
        createSut()

        await sut.load()

        #expect(sut.settings.bufferSize == 256)
        #expect(sut.settings.sampleRate == 88_200)
    }

    @Test
    mutating func load_keepsStoredValuesWithoutTargetDevice() async {
        rawStoreSpy.settings = .fake(bufferSize: 9999, sampleRate: 9999)
        createSut()

        await sut.load()

        #expect(sut.settings.bufferSize == 9999)
        #expect(sut.settings.sampleRate == 9999)
    }

    // MARK: - delegate

    @Test
    mutating func load_notifiesDelegateWhenSettingsChange() async {
        rawStoreSpy.settings = .fake(bufferSize: 256)
        createSut()

        await sut.load()

        #expect(delegateSpy.calls == [.audioSettingsDidChange])
    }

    @Test
    mutating func load_notifiesDelegateWhenTargetDeviceChanges() async {
        targetResolverSpy.resolveResult = .fake()
        createSut()

        await sut.load()

        #expect(delegateSpy.calls == [.audioSettingsDidChange])
    }

    @Test
    mutating func load_notifiesDelegateEvenWhenNothingResolved() async {
        createSut()

        await sut.load()

        #expect(delegateSpy.calls == [.audioSettingsDidChange])
    }

    @Test
    mutating func save_notifiesDelegateAfterStateIsUpdated() async {
        let output = AudioDevice.fake(id: 2, uid: "out-uid")
        devicesProviderSpy.scanDevicesResult = [output]
        createSut()
        await sut.load()
        var seen: AudioDevice??
        let sut = self.sut!
        delegateSpy.onAudioSettingsDidChange = { seen = .some(sut.settings.outputDevice) }

        await sut.save(.fake(outputDevice: output))

        #expect(seen == .some(output))
    }

    // MARK: - device list changes

    @Test
    mutating func deviceListChange_reloads() async {
        createSut()
        await sut.load()
        let output = AudioDevice.fake(id: 2, uid: "out-uid")
        devicesProviderSpy.scanDevicesResult = [output]
        rawStoreSpy.settings = .fake(output: .fake(uid: "out-uid"))

        await coreAudioGatewaySpy.deviceListChangeHandler?()

        #expect(sut.settings.outputDevice == output)
        #expect(rawStoreSpy.calls == [.current, .current])
    }

    @Test
    mutating func deviceListChange_nothingResolved_skipsDelegate() async {
        createSut()
        await sut.load()

        await coreAudioGatewaySpy.deviceListChangeHandler?()

        #expect(delegateSpy.calls == [.audioSettingsDidChange])
    }

    // MARK: - MIDI setup changes

    @Test
    mutating func midiSetupChange_refreshesMidiDevicesWithoutRescan() async {
        createSut()
        await sut.load()
        let keyboard = MidiDevice.fake(ref: 7, uid: 42)
        midiDevicesProviderSpy.devicesResult = [keyboard]

        await midiSetupListenerSpy.changesHandler?()

        #expect(sut.midiDevices == [keyboard])
        #expect(devicesProviderSpy.calls == [.scanDevices])
    }

    @Test
    mutating func midiSetupChange_resolvesSelectedMidiDevicesAgainstLiveList() async {
        let keyboard = MidiDevice.fake(ref: 7, uid: 42)
        midiDevicesProviderSpy.devicesResult = [keyboard]
        rawStoreSpy.settings = .fake(selectedMidiUIDs: [42])
        createSut()
        await sut.load()
        midiDevicesProviderSpy.devicesResult = []

        await midiSetupListenerSpy.changesHandler?()

        #expect(sut.settings.selectedMidiDevices.isEmpty)
        #expect(delegateSpy.calls == [.audioSettingsDidChange, .audioSettingsDidChange])
    }
}
