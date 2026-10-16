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

    // MARK: - connect

    @Test
    mutating func connect_bindsOutputUnitToDevice() async throws {
        let effect = try await Self.makeAVAudioUnit(Self.effectDescription)
        avEngineSpy.outputAudioUnit = Self.outputUnit
        createSut()

        let isConnected = sut.connect(first: effect, last: effect, to: .fake(deviceID: 7, inputDevice: .fake()), in: avEngineSpy)

        #expect(isConnected)
        #expect(audioUnitGatewaySpy.calls == [
            .setEnableIO(true, .input, Self.outputUnit),
            .setEnableIO(false, .output, Self.outputUnit),
            .setCurrentDevice(7, Self.outputUnit)
        ])
    }

    @Test
    mutating func connect_setCurrentDeviceFails_returnsFalseWithoutConnecting() async throws {
        let effect = try await Self.makeAVAudioUnit(Self.effectDescription)
        avEngineSpy.outputAudioUnit = Self.outputUnit
        audioUnitGatewaySpy.setCurrentDeviceError = AudioUnitGatewayError(operation: .setCurrentDevice, status: -1)
        createSut()

        let isConnected = sut.connect(
            first: effect,
            last: effect,
            to: .fake(inputChannels: [1, 2], outputChannels: [1, 2]),
            in: avEngineSpy
        )

        #expect(isConnected == false)
        #expect(avEngineSpy.calls.isEmpty)
    }

    @Test
    mutating func connect_plugsHardwareInputIntoFirstAndLastIntoMainMixer() async throws {
        let first = try await Self.makeAVAudioUnit(Self.effectDescription)
        let last = try await Self.makeAVAudioUnit(Self.delayDescription)
        createSut()

        _ = sut.connect(first: first, last: last, to: .fake(inputChannels: [1], outputChannels: [1, 2]), in: avEngineSpy)

        #expect(avEngineSpy.calls == [
            .connectHardwareInput(first, AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 1)),
            .connectToMainMixer(last, Self.outputFormat(of: last))
        ])
    }

    @Test
    mutating func connect_stereoInputIntoEffect_mapsInputChannels() async throws {
        let effect = try await Self.makeAVAudioUnit(Self.effectDescription)
        let inputUnit = AudioUnit(bitPattern: 0xBADC0DE)!
        avEngineSpy.inputAudioUnit = inputUnit
        createSut()

        _ = sut.connect(first: effect, last: effect, to: .fake(inputDevice: .fake(), inputChannels: [1, 2]), in: avEngineSpy)

        #expect(audioUnitGatewaySpy.calls == [.setChannelMap([0, 1], .input, inputUnit)])
        #expect(avEngineSpy.calls.contains(.connectHardwareInput(effect, AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 2))))
    }

    @Test
    mutating func connect_firstTakesNoAudioInput_skipsHardwareInput() async throws {
        let mixer = try await Self.makeAVAudioUnit(Self.mixerDescription)
        avEngineSpy.inputAudioUnit = AudioUnit(bitPattern: 0xBADC0DE)!
        createSut()

        _ = sut.connect(first: mixer, last: mixer, to: .fake(inputDevice: .fake(), inputChannels: [1, 2]), in: avEngineSpy)

        #expect(avEngineSpy.calls == [.connectToMainMixer(mixer, Self.outputFormat(of: mixer))])
        #expect(audioUnitGatewaySpy.calls.isEmpty)
    }

    @Test
    mutating func connect_stereoOutput_mapsOutputChannels() async throws {
        let effect = try await Self.makeAVAudioUnit(Self.effectDescription)
        avEngineSpy.outputAudioUnit = Self.outputUnit
        audioUnitGatewaySpy.physicalChannelCountResult = 4
        createSut()

        _ = sut.connect(
            first: effect,
            last: effect,
            to: .fake(deviceID: 7, outputDevice: .fake(), outputChannels: [1, 2]),
            in: avEngineSpy
        )

        #expect(audioUnitGatewaySpy.calls == [
            .setEnableIO(false, .input, Self.outputUnit),
            .setEnableIO(true, .output, Self.outputUnit),
            .setCurrentDevice(7, Self.outputUnit),
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

        _ = sut.connect(
            first: effect,
            last: effect,
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

        _ = sut.connect(
            first: effect,
            last: effect,
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

    static let mixerDescription = AudioComponentDescription(
        componentType: kAudioUnitType_Mixer,
        componentSubType: kAudioUnitSubType_MultiChannelMixer,
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
