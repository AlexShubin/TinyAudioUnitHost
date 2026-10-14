//
//  HardwareConnectorTests.swift
//  EngineKitTests
//
//  Created by Alex Shubin on 14.10.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioSettingsKit
import AudioSettingsKitTestSupport
import AudioToolbox
import AudioToolboxGatewayKit
import AudioToolboxGatewayKitTestSupport
import AVFoundation
import Testing
@testable import EngineKit

@Suite @MainActor
struct HardwareConnectorTests {
    var avEngineSpy: AVAudioEngineSpy!
    var audioUnitGatewaySpy: AudioUnitGatewaySpy!
    var audioSettingsSpy: AudioSettingsModelSpy!
    var sut: HardwareConnectorType!

    init() {
        avEngineSpy = AVAudioEngineSpy()
        audioUnitGatewaySpy = AudioUnitGatewaySpy()
        audioSettingsSpy = AudioSettingsModelSpy()
    }

    mutating func createSut() {
        sut = HardwareConnector(
            audioUnitGateway: audioUnitGatewaySpy,
            audioSettings: audioSettingsSpy
        )
    }

    // MARK: - connect

    @Test
    mutating func connect_setupNotMet_returnsFalseWithoutTouchingHardware() async throws {
        let effect = try await Self.makeAVAudioUnit(Self.effectDescription)
        audioSettingsSpy.setup = .unmet([.microphonePermission])
        audioSettingsSpy.targetDevice = .fake()
        avEngineSpy.outputAudioUnit = Self.outputUnit
        createSut()

        let isConnected = await sut.connect(first: effect, last: effect, in: avEngineSpy)

        #expect(isConnected == false)
        #expect(audioUnitGatewaySpy.calls.isEmpty)
        #expect(avEngineSpy.calls.isEmpty)
    }

    @Test
    mutating func connect_withoutTargetDevice_returnsFalseWithoutTouchingHardware() async throws {
        let effect = try await Self.makeAVAudioUnit(Self.effectDescription)
        audioSettingsSpy.setup = .met
        avEngineSpy.outputAudioUnit = Self.outputUnit
        createSut()

        let isConnected = await sut.connect(first: effect, last: effect, in: avEngineSpy)

        #expect(isConnected == false)
        #expect(audioUnitGatewaySpy.calls.isEmpty)
        #expect(avEngineSpy.calls.isEmpty)
    }

    @Test
    mutating func connect_bindsOutputUnitToTargetDevice() async throws {
        let effect = try await Self.makeAVAudioUnit(Self.effectDescription)
        let targetDevice = AudioDevice.fake()
        audioSettingsSpy.settings = .fake(inputDevice: .fake())
        audioSettingsSpy.setup = .met
        audioSettingsSpy.targetDevice = targetDevice
        avEngineSpy.outputAudioUnit = Self.outputUnit
        createSut()

        let isConnected = await sut.connect(first: effect, last: effect, in: avEngineSpy)

        #expect(isConnected)
        #expect(audioUnitGatewaySpy.calls == [
            .setEnableIO(true, .input, Self.outputUnit),
            .setEnableIO(false, .output, Self.outputUnit),
            .setCurrentDevice(targetDevice.id, Self.outputUnit)
        ])
    }

    @Test
    mutating func connect_setCurrentDeviceFails_returnsFalseWithoutConnecting() async throws {
        let effect = try await Self.makeAVAudioUnit(Self.effectDescription)
        audioSettingsSpy.settings = .fake(inputChannel: Self.stereo, outputChannel: Self.stereo)
        audioSettingsSpy.setup = .met
        audioSettingsSpy.targetDevice = .fake()
        avEngineSpy.outputAudioUnit = Self.outputUnit
        audioUnitGatewaySpy.setCurrentDeviceError = AudioUnitGatewayError(operation: .setCurrentDevice, status: -1)
        createSut()

        let isConnected = await sut.connect(first: effect, last: effect, in: avEngineSpy)

        #expect(isConnected == false)
        #expect(avEngineSpy.calls.isEmpty)
    }

    @Test
    mutating func connect_plugsHardwareInputIntoFirstAndLastIntoMainMixer() async throws {
        let first = try await Self.makeAVAudioUnit(Self.effectDescription)
        let last = try await Self.makeAVAudioUnit(Self.delayDescription)
        audioSettingsSpy.settings = .fake(inputChannel: Self.mono, outputChannel: Self.stereo)
        audioSettingsSpy.setup = .met
        audioSettingsSpy.targetDevice = .fake()
        createSut()

        _ = await sut.connect(first: first, last: last, in: avEngineSpy)

        #expect(avEngineSpy.calls == [
            .connectHardwareInput(first, AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 1)),
            .connectToMainMixer(last, Self.outputFormat(of: last))
        ])
    }

    @Test
    mutating func connect_stereoInputIntoEffect_mapsInputChannels() async throws {
        let effect = try await Self.makeAVAudioUnit(Self.effectDescription)
        let inputUnit = AudioUnit(bitPattern: 0xBADC0DE)!
        audioSettingsSpy.settings = .fake(inputDevice: .fake(), inputChannel: Self.stereo)
        audioSettingsSpy.setup = .met
        audioSettingsSpy.targetDevice = .fake()
        avEngineSpy.inputAudioUnit = inputUnit
        createSut()

        _ = await sut.connect(first: effect, last: effect, in: avEngineSpy)

        #expect(audioUnitGatewaySpy.calls == [.setChannelMap([0, 1], .input, inputUnit)])
        #expect(avEngineSpy.calls.contains(.connectHardwareInput(effect, AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 2))))
    }

    @Test
    mutating func connect_firstTakesNoAudioInput_skipsHardwareInput() async throws {
        let mixer = try await Self.makeAVAudioUnit(Self.mixerDescription)
        audioSettingsSpy.settings = .fake(inputDevice: .fake(), inputChannel: Self.stereo)
        audioSettingsSpy.setup = .met
        audioSettingsSpy.targetDevice = .fake()
        avEngineSpy.inputAudioUnit = AudioUnit(bitPattern: 0xBADC0DE)!
        createSut()

        _ = await sut.connect(first: mixer, last: mixer, in: avEngineSpy)

        #expect(avEngineSpy.calls == [.connectToMainMixer(mixer, Self.outputFormat(of: mixer))])
        #expect(audioUnitGatewaySpy.calls.isEmpty)
    }

    @Test
    mutating func connect_stereoOutput_mapsOutputChannels() async throws {
        let effect = try await Self.makeAVAudioUnit(Self.effectDescription)
        let targetDevice = AudioDevice.fake()
        audioSettingsSpy.settings = .fake(outputDevice: .fake(), outputChannel: Self.stereo)
        audioSettingsSpy.setup = .met
        audioSettingsSpy.targetDevice = targetDevice
        avEngineSpy.outputAudioUnit = Self.outputUnit
        audioUnitGatewaySpy.physicalChannelCountResult = 4
        createSut()

        _ = await sut.connect(first: effect, last: effect, in: avEngineSpy)

        #expect(audioUnitGatewaySpy.calls == [
            .setEnableIO(false, .input, Self.outputUnit),
            .setEnableIO(true, .output, Self.outputUnit),
            .setCurrentDevice(targetDevice.id, Self.outputUnit),
            .physicalChannelCount(Self.outputUnit),
            .setChannelMap([0, 1, -1, -1], .output, Self.outputUnit)
        ])
    }

    @Test
    mutating func connect_separateInputAndOutputDevices_offsetsOutputMapPastInputDevice() async throws {
        let effect = try await Self.makeAVAudioUnit(Self.effectDescription)
        let inputDevice = AudioDevice.fake(id: 1, outputChannels: [.fake(id: 1), .fake(id: 2)])
        let outputDevice = AudioDevice.fake(id: 2)
        audioSettingsSpy.settings = .fake(inputDevice: inputDevice, outputDevice: outputDevice, outputChannel: Self.stereo)
        audioSettingsSpy.setup = .met
        audioSettingsSpy.targetDevice = .fake()
        avEngineSpy.outputAudioUnit = Self.outputUnit
        audioUnitGatewaySpy.physicalChannelCountResult = 4
        createSut()

        _ = await sut.connect(first: effect, last: effect, in: avEngineSpy)

        #expect(audioUnitGatewaySpy.calls.last == .setChannelMap([-1, -1, 0, 1], .output, Self.outputUnit))
    }

    // MARK: - disconnect

    @Test
    mutating func disconnect_unplugsMainMixerAndHardwareInput() {
        createSut()

        sut.disconnect(in: avEngineSpy)

        #expect(avEngineSpy.calls == [.disconnectMainMixerInput, .disconnectHardwareInput])
    }
}

// MARK: - Test fixtures

private extension HardwareConnectorTests {
    static let outputUnit = AudioUnit(bitPattern: 0xC0FFEE)!

    static let effectDescription = AudioComponentDescription(
        componentType: kAudioUnitType_Effect,
        componentSubType: kAudioUnitSubType_DynamicsProcessor,
        componentManufacturer: kAudioUnitManufacturer_Apple,
        componentFlags: 0,
        componentFlagsMask: 0
    )

    static let delayDescription = AudioComponentDescription(
        componentType: kAudioUnitType_Effect,
        componentSubType: kAudioUnitSubType_Delay,
        componentManufacturer: kAudioUnitManufacturer_Apple,
        componentFlags: 0,
        componentFlagsMask: 0
    )

    static let mixerDescription = AudioComponentDescription(
        componentType: kAudioUnitType_Mixer,
        componentSubType: kAudioUnitSubType_MultiChannelMixer,
        componentManufacturer: kAudioUnitManufacturer_Apple,
        componentFlags: 0,
        componentFlagsMask: 0
    )

    static let mono = SelectedChannel.mono(AudioChannel(id: 1, name: "In 1"))

    static let stereo = SelectedChannel.stereo(
        l: AudioChannel(id: 1, name: "L"),
        r: AudioChannel(id: 2, name: "R")
    )

    static func outputFormat(of avAudioUnit: AVAudioUnit) -> AVAudioFormat? {
        AVAudioFormat(
            standardFormatWithSampleRate: 48_000,
            channels: avAudioUnit.auAudioUnit.outputBusses[0].format.channelCount
        )
    }

    static func makeAVAudioUnit(_ desc: AudioComponentDescription) async throws -> AVAudioUnit {
        try await AVAudioUnit.instantiate(with: desc, options: [])
    }
}
