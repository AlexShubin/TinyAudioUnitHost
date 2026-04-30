//
//  EngineTests.swift
//  EngineKitTests
//
//  Created by Alex Shubin on 30.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioToolbox
import AVFoundation
import Common
import EngineKitTestSupport
import StorageKit
import StorageKitTestSupport
import Testing
@testable import EngineKit

@Suite
struct EngineTests {
    var avEngineMock: AVAudioEngineMock!
    nonisolated(unsafe) var inputMixerMock: AVAudioMixerNode!
    var avAudioUnitFactoryMock: AVAudioUnitFactoryMock!
    var coreAudioGatewayMock: CoreAudioGatewayMock!
    var coreMidiManagerMock: CoreMidiManagerMock!
    var audioSettingsStoreMock: AudioSettingsStoreMock!
    var aggregateDeviceManagerMock: AggregateDeviceManagerMock!
    var sut: EngineType!

    init() {
        avEngineMock = AVAudioEngineMock()
        inputMixerMock = AVAudioMixerNode()
        avAudioUnitFactoryMock = AVAudioUnitFactoryMock()
        coreAudioGatewayMock = CoreAudioGatewayMock()
        coreMidiManagerMock = CoreMidiManagerMock()
        audioSettingsStoreMock = AudioSettingsStoreMock()
        aggregateDeviceManagerMock = AggregateDeviceManagerMock()
        createSut()
    }

    mutating func createSut() {
        sut = Engine(
            engine: avEngineMock,
            inputMixer: inputMixerMock,
            avAudioUnitFactory: avAudioUnitFactoryMock,
            coreAudioGateway: coreAudioGatewayMock,
            coreMidiManager: coreMidiManagerMock,
            settingsStore: audioSettingsStoreMock,
            aggregateDeviceManager: aggregateDeviceManagerMock
        )
    }

    @Test
    func init_attachesInputMixer() async {
        #expect(avEngineMock.calls == [.attach(inputMixerMock)])
    }

    @Test
    func load_factoryFailure_returnsNilAndShortCircuits() async {
        avAudioUnitFactoryMock.instantiateResult = .failure(TestError.factoryFailed)

        let result = await sut.load(component: Self.effectComponent)

        #expect(result == nil)
        #expect(avEngineMock.calls == [
            .attach(inputMixerMock),
            .stop,
            .disconnectMainMixerInput,
            .disconnectNodeOutput(inputMixerMock),
            .disconnectHardwareInput
        ])
        #expect(coreMidiManagerMock.calls == [.teardownMIDI])
        #expect(avAudioUnitFactoryMock.calls == [.instantiate(Self.effectDescription, .loadOutOfProcess)])
    }

    @Test
    func load_happyPath_attachesAU_setsUpMIDI_andStarts() async throws {
        let avAudioUnit = try await Self.makeAVAudioUnit(Self.effectDescription)
        avAudioUnitFactoryMock.instantiateResult = .success(avAudioUnit)

        let result = await sut.load(component: Self.effectComponent)

        #expect(result?.component == Self.effectComponent)
        #expect(avEngineMock.calls == [
            .attach(inputMixerMock),
            .stop,
            .disconnectMainMixerInput,
            .disconnectNodeOutput(inputMixerMock),
            .disconnectHardwareInput,
            .attach(avAudioUnit),
            .start
        ])
        #expect(coreMidiManagerMock.calls == [.teardownMIDI, .setupMIDI(avAudioUnit.auAudioUnit)])
    }

    @Test
    func load_replacesPreviousAU_detachesOldAndTearsDownMIDI() async throws {
        let firstAU = try await Self.makeAVAudioUnit(Self.effectDescription)
        let secondAU = try await Self.makeAVAudioUnit(Self.effectDescription)
        avAudioUnitFactoryMock.instantiateResult = .success(firstAU)

        _ = await sut.load(component: Self.effectComponent)
        avAudioUnitFactoryMock.instantiateResult = .success(secondAU)

        _ = await sut.load(component: Self.effectComponent)

        #expect(avEngineMock.calls == [
            .attach(inputMixerMock),
            .stop,
            .disconnectMainMixerInput,
            .disconnectNodeOutput(inputMixerMock),
            .disconnectHardwareInput,
            .attach(firstAU),
            .start,
            .stop,
            .disconnectMainMixerInput,
            .disconnectNodeOutput(inputMixerMock),
            .disconnectHardwareInput,
            .detach(firstAU),
            .attach(secondAU),
            .start
        ])
        #expect(coreMidiManagerMock.calls == [
            .teardownMIDI, .setupMIDI(firstAU.auAudioUnit),
            .teardownMIDI, .setupMIDI(secondAU.auAudioUnit)
        ])
        #expect(avAudioUnitFactoryMock.calls == [
            .instantiate(Self.effectDescription, .loadOutOfProcess),
            .instantiate(Self.effectDescription, .loadOutOfProcess)
        ])
    }

    @Test
    mutating func load_withTarget_bindsDeviceAndSetsBuffer() async throws {
        let avAudioUnit = try await Self.makeAVAudioUnit(Self.effectDescription)
        let outputAU = AudioUnit(bitPattern: 0xC0FFEE)!

        avEngineMock.outputAudioUnit = outputAU
        avAudioUnitFactoryMock.instantiateResult = .success(avAudioUnit)
        aggregateDeviceManagerMock = AggregateDeviceManagerMock(resolveTargetResult: Self.makeTarget())
        await audioSettingsStoreMock.update { $0 = AudioSettings(input: .empty, output: .empty, bufferSize: 256) }
        createSut()

        _ = await sut.load(component: Self.effectComponent)

        #expect(coreAudioGatewayMock.calls == [
            .setEnableIO(true, kAudioUnitScope_Input, 1, outputAU),
            .setEnableIO(true, kAudioUnitScope_Output, 0, outputAU),
            .setCurrentDevice(Self.deviceID, outputAU),
            .setBufferSize(256, Self.deviceID)
        ])
    }

    @Test
    mutating func load_withTargetButNoBufferSize_skipsBuffer() async throws {
        let avAudioUnit = try await Self.makeAVAudioUnit(Self.effectDescription)
        let outputAU = AudioUnit(bitPattern: 0xC0FFEE)!

        avEngineMock.outputAudioUnit = outputAU
        avAudioUnitFactoryMock.instantiateResult = .success(avAudioUnit)
        aggregateDeviceManagerMock = AggregateDeviceManagerMock(resolveTargetResult: Self.makeTarget())
        createSut()

        _ = await sut.load(component: Self.effectComponent)

        #expect(coreAudioGatewayMock.calls == [
            .setEnableIO(true, kAudioUnitScope_Input, 1, outputAU),
            .setEnableIO(true, kAudioUnitScope_Output, 0, outputAU),
            .setCurrentDevice(Self.deviceID, outputAU)
        ])
    }

    @Test
    func load_withoutTarget_skipsDeviceBindingAndBuffer() async throws {
        let avAudioUnit = try await Self.makeAVAudioUnit(Self.effectDescription)
        let outputAU = AudioUnit(bitPattern: 0xC0FFEE)!

        avEngineMock.outputAudioUnit = outputAU
        avAudioUnitFactoryMock.instantiateResult = .success(avAudioUnit)
        await audioSettingsStoreMock.update { $0 = AudioSettings(input: .empty, output: .empty, bufferSize: 256) }

        _ = await sut.load(component: Self.effectComponent)

        #expect(coreAudioGatewayMock.calls.isEmpty)
    }

    @Test
    mutating func load_withStereoInputOnEffectAU_setsInputChannelMap() async throws {
        let avAudioUnit = try await Self.makeAVAudioUnit(Self.effectDescription)
        let inputAU = AudioUnit(bitPattern: 0xBADC0DE)!
        let stereo = SelectedChannel.stereo(
            l: AudioChannel(id: 1, name: "L"),
            r: AudioChannel(id: 2, name: "R")
        )

        avEngineMock.inputAudioUnit = inputAU
        avAudioUnitFactoryMock.instantiateResult = .success(avAudioUnit)
        aggregateDeviceManagerMock = AggregateDeviceManagerMock(resolveTargetResult: Self.makeTarget(inputOffset: 2))
        await audioSettingsStoreMock.update {
            $0 = AudioSettings(
                input: DeviceSettings(device: nil, selectedChannel: stereo),
                output: .empty
            )
        }
        createSut()

        _ = await sut.load(component: Self.effectComponent)

        let userFormat = AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 2)
        let auInputFormat = AVAudioFormat(
            standardFormatWithSampleRate: 48_000,
            channels: avAudioUnit.auAudioUnit.inputBusses[0].format.channelCount
        )
        #expect(coreAudioGatewayMock.calls == [.setChannelMap([2, 3], 1, inputAU)])
        #expect(avEngineMock.calls == [
            .attach(inputMixerMock),
            .attach(inputMixerMock),
            .stop,
            .disconnectMainMixerInput,
            .disconnectNodeOutput(inputMixerMock),
            .disconnectHardwareInput,
            .attach(avAudioUnit),
            .connectHardwareInput(inputMixerMock, userFormat),
            .connect(inputMixerMock, avAudioUnit, auInputFormat),
            .start
        ])
    }

    @Test
    mutating func load_withNonEffectAU_skipsInputConnectionEvenIfChannelSelected() async throws {
        let avAudioUnit = try await Self.makeAVAudioUnit(Self.mixerDescription)
        let inputAU = AudioUnit(bitPattern: 0xBADC0DE)!
        let stereo = SelectedChannel.stereo(
            l: AudioChannel(id: 1, name: "L"),
            r: AudioChannel(id: 2, name: "R")
        )

        avEngineMock.inputAudioUnit = inputAU
        avAudioUnitFactoryMock.instantiateResult = .success(avAudioUnit)
        aggregateDeviceManagerMock = AggregateDeviceManagerMock(resolveTargetResult: Self.makeTarget())
        await audioSettingsStoreMock.update {
            $0 = AudioSettings(
                input: DeviceSettings(device: nil, selectedChannel: stereo),
                output: .empty
            )
        }
        createSut()

        _ = await sut.load(component: Self.mixerComponent)

        #expect(coreAudioGatewayMock.calls.isEmpty)
        #expect(avEngineMock.calls == [
            .attach(inputMixerMock),
            .attach(inputMixerMock),
            .stop,
            .disconnectMainMixerInput,
            .disconnectNodeOutput(inputMixerMock),
            .disconnectHardwareInput,
            .attach(avAudioUnit),
            .start
        ])
    }

    @Test
    mutating func load_withStereoOutput_setsOutputChannelMap() async throws {
        let avAudioUnit = try await Self.makeAVAudioUnit(Self.effectDescription)
        let outputAU = AudioUnit(bitPattern: 0xC0FFEE)!
        let stereo = SelectedChannel.stereo(
            l: AudioChannel(id: 1, name: "L"),
            r: AudioChannel(id: 2, name: "R")
        )

        avEngineMock.outputAudioUnit = outputAU
        avAudioUnitFactoryMock.instantiateResult = .success(avAudioUnit)
        coreAudioGatewayMock.physicalChannelCountResult = 4
        aggregateDeviceManagerMock = AggregateDeviceManagerMock(resolveTargetResult: Self.makeTarget())
        await audioSettingsStoreMock.update {
            $0 = AudioSettings(
                input: .empty,
                output: DeviceSettings(device: nil, selectedChannel: stereo)
            )
        }
        createSut()

        _ = await sut.load(component: Self.effectComponent)

        let outputFormat = AVAudioFormat(
            standardFormatWithSampleRate: 48_000,
            channels: avAudioUnit.auAudioUnit.outputBusses[0].format.channelCount
        )
        #expect(coreAudioGatewayMock.calls == [
            .setEnableIO(true, kAudioUnitScope_Input, 1, outputAU),
            .setEnableIO(true, kAudioUnitScope_Output, 0, outputAU),
            .setCurrentDevice(Self.deviceID, outputAU),
            .physicalChannelCount(outputAU),
            .setChannelMap([0, 1, -1, -1], 0, outputAU)
        ])
        #expect(avEngineMock.calls == [
            .attach(inputMixerMock),
            .attach(inputMixerMock),
            .stop,
            .disconnectMainMixerInput,
            .disconnectNodeOutput(inputMixerMock),
            .disconnectHardwareInput,
            .attach(avAudioUnit),
            .connectToMainMixer(avAudioUnit, outputFormat),
            .start
        ])
    }

    @Test
    func reload_doesNotCallFactoryOrTouchMIDI() async {
        await sut.reload()

        #expect(avAudioUnitFactoryMock.calls.isEmpty)
        #expect(coreMidiManagerMock.calls.isEmpty)
        #expect(avEngineMock.calls == [
            .attach(inputMixerMock),
            .stop,
            .disconnectMainMixerInput,
            .disconnectNodeOutput(inputMixerMock),
            .disconnectHardwareInput,
            .start
        ])
    }
}

// MARK: - Test fixtures

private extension EngineTests {
    enum TestError: Error { case factoryFailed }

    static let deviceID: AudioDeviceID = 42

    static let effectDescription = AudioComponentDescription(
        componentType: kAudioUnitType_Effect,
        componentSubType: kAudioUnitSubType_DynamicsProcessor,
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

    static var effectComponent: AudioUnitComponent {
        AudioUnitComponent(name: "Dyn", manufacturer: "Apple", componentDescription: effectDescription)
    }

    static var mixerComponent: AudioUnitComponent {
        AudioUnitComponent(name: "Mix", manufacturer: "Apple", componentDescription: mixerDescription)
    }

    static func makeAVAudioUnit(_ desc: AudioComponentDescription) async throws -> AVAudioUnit {
        try await AVAudioUnit.instantiate(with: desc, options: [])
    }

    static func makeTarget(inputOffset: Int = 0, outputOffset: Int = 0) -> TargetAudioDevice {
        let device = AudioDevice(
            id: deviceID,
            uid: "uid",
            name: "Test Device",
            inputChannels: [],
            outputChannels: [],
            availableBufferSizes: []
        )
        return TargetAudioDevice(
            device: device,
            inputSource: device,
            outputSource: device,
            inputOffset: inputOffset,
            outputOffset: outputOffset
        )
    }
}
