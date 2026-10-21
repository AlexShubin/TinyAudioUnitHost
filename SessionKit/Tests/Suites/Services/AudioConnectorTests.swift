//
//  AudioConnectorTests.swift
//  SessionKitTests
//
//  Created by Alex Shubin on 14.10.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioToolbox
import AudioToolboxGatewayKit
import AudioToolboxGatewayKitTestSupport
import AVFoundation
import SessionKitTestSupport
import Testing
@testable import SessionKit

@Suite @MainActor
struct AudioConnectorTests {
    var avEngineSpy: AVAudioEngineSpy!
    var audioUnitGatewaySpy: AudioUnitGatewaySpy!
    var sut: AudioConnectorType!

    init() {
        avEngineSpy = AVAudioEngineSpy()
        audioUnitGatewaySpy = AudioUnitGatewaySpy()
    }

    mutating func createSut() {
        sut = AudioConnector(audioUnitGateway: audioUnitGatewaySpy)
    }

    // MARK: - bind

    @Test
    mutating func bind_bindsOutputUnitToDevice() {
        avEngineSpy.outputAudioUnit = Self.outputUnit
        createSut()

        let isBound = sut.bind(.fake(deviceID: 7, inputDevice: .fake()), in: avEngineSpy)

        #expect(isBound)
        #expect(audioUnitGatewaySpy.calls == [
            .setEnableIO(true, .input, Self.outputUnit),
            .setEnableIO(false, .output, Self.outputUnit),
            .setCurrentDevice(7, Self.outputUnit)
        ])
    }

    @Test
    mutating func bind_setCurrentDeviceFails_returnsFalse() {
        avEngineSpy.outputAudioUnit = Self.outputUnit
        audioUnitGatewaySpy.setCurrentDeviceError = AudioUnitGatewayError(operation: .setCurrentDevice, status: -1)
        createSut()

        let isBound = sut.bind(.fake(), in: avEngineSpy)

        #expect(isBound == false)
    }

    @Test
    mutating func bind_withoutOutputUnit_returnsTrueWithoutTouchingDevice() {
        createSut()

        let isBound = sut.bind(.fake(), in: avEngineSpy)

        #expect(isBound)
        #expect(audioUnitGatewaySpy.calls.isEmpty)
    }

    // MARK: - connect

    @Test
    mutating func connect_plugsHardwareInputIntoInputAndOutputIntoMainMixer() async throws {
        let input = try await Self.makeAVAudioUnit(Self.effectDescription)
        let output = try await Self.makeAVAudioUnit(Self.delayDescription)
        createSut()

        sut.connect(input: input, output: output, to: .fake(inputChannels: [1], outputChannels: [1, 2]), in: avEngineSpy)

        #expect(avEngineSpy.calls == [
            .connectHardwareInput(input, AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 1)),
            .connectToMainMixer(output, Self.outputFormat(of: output))
        ])
    }

    @Test
    mutating func connect_stereoInputIntoEffect_mapsInputChannels() async throws {
        let effect = try await Self.makeAVAudioUnit(Self.effectDescription)
        let inputUnit = AudioUnit(bitPattern: 0xBADC0DE)!
        avEngineSpy.inputAudioUnit = inputUnit
        createSut()

        sut.connect(input: effect, output: effect, to: .fake(inputDevice: .fake(), inputChannels: [1, 2]), in: avEngineSpy)

        #expect(audioUnitGatewaySpy.calls == [.setChannelMap([0, 1], .input, inputUnit)])
        #expect(avEngineSpy.calls.contains(.connectHardwareInput(effect, AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 2))))
    }

    @Test
    mutating func connect_withoutInput_skipsHardwareInput() async throws {
        let effect = try await Self.makeAVAudioUnit(Self.effectDescription)
        avEngineSpy.inputAudioUnit = AudioUnit(bitPattern: 0xBADC0DE)!
        createSut()

        sut.connect(input: nil, output: effect, to: .fake(inputDevice: .fake(), inputChannels: [1, 2]), in: avEngineSpy)

        #expect(avEngineSpy.calls == [.connectToMainMixer(effect, Self.outputFormat(of: effect))])
        #expect(audioUnitGatewaySpy.calls.isEmpty)
    }

    @Test
    mutating func connect_stereoOutput_mapsOutputChannels() async throws {
        let effect = try await Self.makeAVAudioUnit(Self.effectDescription)
        avEngineSpy.outputAudioUnit = Self.outputUnit
        audioUnitGatewaySpy.physicalChannelCountResult = 4
        createSut()

        sut.connect(
            input: effect,
            output: effect,
            to: .fake(outputDevice: .fake(), outputChannels: [1, 2]),
            in: avEngineSpy
        )

        #expect(audioUnitGatewaySpy.calls == [
            .physicalChannelCount(Self.outputUnit),
            .setChannelMap([0, 1, -1, -1], .output, Self.outputUnit)
        ])
    }

    @Test
    mutating func connect_separateInputAndOutputDevices_offsetsOutputMapPastInputDevice() async throws {
        let effect = try await Self.makeAVAudioUnit(Self.effectDescription)
        avEngineSpy.outputAudioUnit = Self.outputUnit
        audioUnitGatewaySpy.physicalChannelCountResult = 4
        createSut()

        sut.connect(
            input: effect,
            output: effect,
            to: .fake(
                inputDevice: .fake(id: 1, outputChannelCount: 2),
                outputDevice: .fake(id: 2),
                outputChannels: [1, 2]
            ),
            in: avEngineSpy
        )

        #expect(audioUnitGatewaySpy.calls.last == .setChannelMap([-1, -1, 0, 1], .output, Self.outputUnit))
    }

    @Test
    mutating func connect_sameInputAndOutputDevice_keepsOutputMapUnshifted() async throws {
        let effect = try await Self.makeAVAudioUnit(Self.effectDescription)
        avEngineSpy.outputAudioUnit = Self.outputUnit
        audioUnitGatewaySpy.physicalChannelCountResult = 4
        createSut()

        sut.connect(
            input: effect,
            output: effect,
            to: .fake(
                inputDevice: .fake(id: 1, outputChannelCount: 2),
                outputDevice: .fake(id: 1, outputChannelCount: 2),
                outputChannels: [1, 2]
            ),
            in: avEngineSpy
        )

        #expect(audioUnitGatewaySpy.calls.last == .setChannelMap([0, 1, -1, -1], .output, Self.outputUnit))
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

private extension AudioConnectorTests {
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
