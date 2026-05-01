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
import CommonTestSupport
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
    mutating func init_attachesInputMixer() async {
        createSut()

        #expect(avEngineMock.calls == [.attach(inputMixerMock)])
    }

    @Test
    mutating func load_factoryFailure_returnsNilAndShortCircuits() async {
        avAudioUnitFactoryMock.instantiateResult = .failure(TestError.factoryFailed)
        createSut()

        let result = await sut.load(component: Self.effectComponent)

        #expect(result == nil)
        #expect(avAudioUnitFactoryMock.calls == [.instantiate(Self.effectDescription, .loadOutOfProcess)])
        #expect(coreMidiManagerMock.calls == [.teardownMIDI])
        #expect(!avEngineMock.calls.contains(.start))
    }

    @Test
    mutating func load_happyPath_attachesAU_setsUpMIDI_andStarts() async throws {
        let avAudioUnit = try await Self.makeAVAudioUnit(Self.effectDescription)
        avAudioUnitFactoryMock.instantiateResult = .success(avAudioUnit)
        createSut()

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
    mutating func load_replacesPreviousAU_detachesOldAndTearsDownMIDI() async throws {
        let firstAU = try await Self.makeAVAudioUnit(Self.effectDescription)
        let secondAU = try await Self.makeAVAudioUnit(Self.effectDescription)
        avAudioUnitFactoryMock.instantiateResult = .success(firstAU)
        createSut()

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
    mutating func load_withTarget_appliesSampleRateAndBuffer() async throws {
        let avAudioUnit = try await Self.makeAVAudioUnit(Self.effectDescription)
        let outputAU = AudioUnit(bitPattern: 0xC0FFEE)!

        let target = TargetAudioDevice.fake()
        avEngineMock.outputAudioUnit = outputAU
        avAudioUnitFactoryMock.instantiateResult = .success(avAudioUnit)
        await aggregateDeviceManagerMock.setResolveTargetResult(target)
        await audioSettingsStoreMock.setSettings(.fake(bufferSize: 256, sampleRate: 48_000))
        createSut()

        _ = await sut.load(component: Self.effectComponent)

        #expect(coreAudioGatewayMock.calls == [
            .setEnableIO(true, kAudioUnitScope_Input, 1, outputAU),
            .setEnableIO(true, kAudioUnitScope_Output, 0, outputAU),
            .setCurrentDevice(target.device.id, outputAU),
            .setSampleRate(48_000, target.device.id),
            .setBufferSize(256, target.device.id)
        ])
    }

    @Test
    mutating func load_withTargetAndSampleRateOnly_setsSampleRateNotBuffer() async throws {
        let avAudioUnit = try await Self.makeAVAudioUnit(Self.effectDescription)
        let outputAU = AudioUnit(bitPattern: 0xC0FFEE)!

        let target = TargetAudioDevice.fake()
        avEngineMock.outputAudioUnit = outputAU
        avAudioUnitFactoryMock.instantiateResult = .success(avAudioUnit)
        await aggregateDeviceManagerMock.setResolveTargetResult(target)
        await audioSettingsStoreMock.setSettings(.fake(sampleRate: 48_000))
        createSut()

        _ = await sut.load(component: Self.effectComponent)

        #expect(coreAudioGatewayMock.calls == [
            .setEnableIO(true, kAudioUnitScope_Input, 1, outputAU),
            .setEnableIO(true, kAudioUnitScope_Output, 0, outputAU),
            .setCurrentDevice(target.device.id, outputAU),
            .setSampleRate(48_000, target.device.id)
        ])
    }

    @Test
    mutating func load_withTargetButNoBufferSize_skipsBuffer() async throws {
        let avAudioUnit = try await Self.makeAVAudioUnit(Self.effectDescription)
        let outputAU = AudioUnit(bitPattern: 0xC0FFEE)!

        let target = TargetAudioDevice.fake()
        avEngineMock.outputAudioUnit = outputAU
        avAudioUnitFactoryMock.instantiateResult = .success(avAudioUnit)
        await aggregateDeviceManagerMock.setResolveTargetResult(target)
        createSut()

        _ = await sut.load(component: Self.effectComponent)

        #expect(coreAudioGatewayMock.calls == [
            .setEnableIO(true, kAudioUnitScope_Input, 1, outputAU),
            .setEnableIO(true, kAudioUnitScope_Output, 0, outputAU),
            .setCurrentDevice(target.device.id, outputAU)
        ])
    }

    @Test
    mutating func load_withoutTarget_skipsDeviceBindingAndBuffer() async throws {
        let avAudioUnit = try await Self.makeAVAudioUnit(Self.effectDescription)
        let outputAU = AudioUnit(bitPattern: 0xC0FFEE)!

        avEngineMock.outputAudioUnit = outputAU
        avAudioUnitFactoryMock.instantiateResult = .success(avAudioUnit)
        await audioSettingsStoreMock.setSettings(.fake(bufferSize: 256))
        createSut()

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
        await aggregateDeviceManagerMock.setResolveTargetResult(.fake(inputOffset: 2))
        await audioSettingsStoreMock.setSettings(.fake(input: .fake(selectedChannel: stereo)))
        createSut()

        _ = await sut.load(component: Self.effectComponent)

        let userFormat = AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 2)
        #expect(coreAudioGatewayMock.calls == [.setChannelMap([2, 3], 1, inputAU)])
        #expect(avEngineMock.calls.contains(.connectHardwareInput(inputMixerMock, userFormat)))
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
        await aggregateDeviceManagerMock.setResolveTargetResult(.fake())
        await audioSettingsStoreMock.setSettings(.fake(input: .fake(selectedChannel: stereo)))
        createSut()

        _ = await sut.load(component: Self.mixerComponent)

        #expect(coreAudioGatewayMock.calls.isEmpty)
        #expect(!avEngineMock.calls.contains { if case .connectHardwareInput = $0 { true } else { false } })
    }

    @Test
    mutating func load_withStereoOutput_setsOutputChannelMap() async throws {
        let avAudioUnit = try await Self.makeAVAudioUnit(Self.effectDescription)
        let outputAU = AudioUnit(bitPattern: 0xC0FFEE)!
        let stereo = SelectedChannel.stereo(
            l: AudioChannel(id: 1, name: "L"),
            r: AudioChannel(id: 2, name: "R")
        )

        let target = TargetAudioDevice.fake()
        avEngineMock.outputAudioUnit = outputAU
        avAudioUnitFactoryMock.instantiateResult = .success(avAudioUnit)
        coreAudioGatewayMock.physicalChannelCountResult = 4
        await aggregateDeviceManagerMock.setResolveTargetResult(target)
        await audioSettingsStoreMock.setSettings(.fake(output: .fake(selectedChannel: stereo)))
        createSut()

        _ = await sut.load(component: Self.effectComponent)

        let outputFormat = AVAudioFormat(
            standardFormatWithSampleRate: 48_000,
            channels: avAudioUnit.auAudioUnit.outputBusses[0].format.channelCount
        )
        #expect(coreAudioGatewayMock.calls == [
            .setEnableIO(true, kAudioUnitScope_Input, 1, outputAU),
            .setEnableIO(true, kAudioUnitScope_Output, 0, outputAU),
            .setCurrentDevice(target.device.id, outputAU),
            .physicalChannelCount(outputAU),
            .setChannelMap([0, 1, -1, -1], 0, outputAU)
        ])
        #expect(avEngineMock.calls.contains(.connectToMainMixer(avAudioUnit, outputFormat)))
    }

    @Test
    mutating func reload_doesNotCallFactoryOrTouchMIDI() async {
        createSut()

        await sut.reload()

        #expect(avAudioUnitFactoryMock.calls.isEmpty)
        #expect(coreMidiManagerMock.calls.isEmpty)
    }
}

// MARK: - Test fixtures

private extension EngineTests {
    enum TestError: Error { case factoryFailed }

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
}
