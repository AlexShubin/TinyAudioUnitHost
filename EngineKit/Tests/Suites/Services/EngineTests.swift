//
//  EngineTests.swift
//  EngineKitTests
//
//  Created by Alex Shubin on 30.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioSettingsKit
import AudioSettingsKitTestSupport
import AudioToolbox
import AudioUnitsKit
import AVFoundation
import EngineKitTestSupport
import Testing
@testable import EngineKit

@Suite @MainActor
struct EngineTests {
    var avEngineSpy: AVAudioEngineSpy!
    nonisolated(unsafe) var inputMixerSpy: AVAudioMixerNode!
    var avAudioUnitFactorySpy: AVAudioUnitFactorySpy!
    var coreAudioGatewaySpy: CoreAudioGatewaySpy!
    var midiManagerSpy: MidiManagerSpy!
    var audioSettingsSpy: AudioSettingsModelSpy!
    var sut: EngineType!

    init() {
        avEngineSpy = AVAudioEngineSpy()
        inputMixerSpy = AVAudioMixerNode()
        avAudioUnitFactorySpy = AVAudioUnitFactorySpy()
        coreAudioGatewaySpy = CoreAudioGatewaySpy()
        midiManagerSpy = MidiManagerSpy()
        audioSettingsSpy = AudioSettingsModelSpy()
    }

    mutating func createSut() {
        sut = Engine(
            engine: avEngineSpy,
            inputMixer: inputMixerSpy,
            avAudioUnitFactory: avAudioUnitFactorySpy,
            coreAudioGateway: coreAudioGatewaySpy,
            midiManager: midiManagerSpy,
            audioSettings: audioSettingsSpy
        )
    }

    @Test
    mutating func init_attachesInputMixer() async {
        createSut()

        #expect(avEngineSpy.calls == [.attach(inputMixerSpy)])
    }

    @Test
    mutating func load_factoryFailure_throwsAndShortCircuits() async {
        avAudioUnitFactorySpy.instantiateResult = .failure(TestError.factoryFailed)
        createSut()

        var thrown: Error?
        do {
            _ = try await sut.load(component: Self.effectComponent, state: nil)
        } catch {
            thrown = error
        }

        #expect(thrown as? EngineLoadError == .audioUnitInstantiationFailed)
        #expect(avAudioUnitFactorySpy.calls == [.instantiate(Self.effectDescription, .loadOutOfProcess)])
        #expect(midiManagerSpy.calls == [.teardownMIDI])
        #expect(!avEngineSpy.calls.contains(.start))
    }

    @Test
    mutating func load_happyPath_attachesAU_setsUpMIDI_andStarts() async throws {
        let avAudioUnit = try await Self.makeAVAudioUnit(Self.effectDescription)
        avAudioUnitFactorySpy.instantiateResult = .success(avAudioUnit)
        createSut()

        let result = try await sut.load(component: Self.effectComponent, state: nil)

        #expect(result.component == Self.effectComponent)
        #expect(avEngineSpy.calls == [
            .attach(inputMixerSpy),
            .stop,
            .disconnectMainMixerInput,
            .disconnectNodeOutput(inputMixerSpy),
            .disconnectHardwareInput,
            .attach(avAudioUnit),
            .start
        ])
        #expect(midiManagerSpy.calls == [.teardownMIDI, .setupMIDI(result)])
    }

    @Test
    mutating func load_withState_appliesStateToAU() async throws {
        let avAudioUnit = try await Self.makeAVAudioUnit(Self.effectDescription)
        let parameter = try #require(avAudioUnit.auAudioUnit.parameterTree?.allParameters.first)

        parameter.value = parameter.maxValue
        let fullState = try #require(avAudioUnit.auAudioUnit.fullState)
        let stateAtMax = try PropertyListSerialization.data(fromPropertyList: fullState, format: .binary, options: 0)
        parameter.value = parameter.minValue

        avAudioUnitFactorySpy.instantiateResult = .success(avAudioUnit)
        createSut()

        try await Task(priority: .utility) { [sut] in
            _ = try await sut!.load(component: Self.effectComponent, state: stateAtMax)
        }.value

        #expect(parameter.value == parameter.maxValue)
    }

    @Test
    mutating func load_replacesPreviousAU_detachesOldAndTearsDownMIDI() async throws {
        let firstAU = try await Self.makeAVAudioUnit(Self.effectDescription)
        let secondAU = try await Self.makeAVAudioUnit(Self.effectDescription)
        avAudioUnitFactorySpy.instantiateResult = .success(firstAU)
        createSut()

        let firstResult = try await sut.load(component: Self.effectComponent, state: nil)
        avAudioUnitFactorySpy.instantiateResult = .success(secondAU)

        let secondResult = try await sut.load(component: Self.effectComponent, state: nil)

        #expect(avEngineSpy.calls == [
            .attach(inputMixerSpy),
            .stop,
            .disconnectMainMixerInput,
            .disconnectNodeOutput(inputMixerSpy),
            .disconnectHardwareInput,
            .attach(firstAU),
            .start,
            .stop,
            .disconnectMainMixerInput,
            .disconnectNodeOutput(inputMixerSpy),
            .disconnectHardwareInput,
            .detach(firstAU),
            .attach(secondAU),
            .start
        ])
        #expect(midiManagerSpy.calls == [
            .teardownMIDI, .setupMIDI(firstResult),
            .teardownMIDI, .setupMIDI(secondResult)
        ])
        #expect(avAudioUnitFactorySpy.calls == [
            .instantiate(Self.effectDescription, .loadOutOfProcess),
            .instantiate(Self.effectDescription, .loadOutOfProcess)
        ])
    }

    @Test
    mutating func load_withTarget_bindsOutputUnitToDevice() async throws {
        let avAudioUnit = try await Self.makeAVAudioUnit(Self.effectDescription)
        let outputAU = AudioUnit(bitPattern: 0xC0FFEE)!

        let targetDevice = AudioDevice.fake()
        audioSettingsSpy.settings = .fake(inputDevice: .fake())
        audioSettingsSpy.targetDevice = targetDevice
        avEngineSpy.outputAudioUnit = outputAU
        avAudioUnitFactorySpy.instantiateResult = .success(avAudioUnit)
        createSut()

        _ = try await sut.load(component: Self.effectComponent, state: nil)

        #expect(coreAudioGatewaySpy.calls == [
            .setEnableIO(true, kAudioUnitScope_Input, 1, outputAU),
            .setEnableIO(false, kAudioUnitScope_Output, 0, outputAU),
            .setCurrentDevice(targetDevice.id, outputAU)
        ])
    }

    @Test
    mutating func load_withoutTarget_skipsDeviceBinding() async {
        avAudioUnitFactorySpy.instantiateResult = .failure(TestError.factoryFailed)
        createSut()

        _ = try? await sut.load(component: Self.effectComponent, state: nil)

        #expect(coreAudioGatewaySpy.calls.isEmpty)
    }

    @Test
    mutating func load_withStereoInputOnEffectAU_setsInputChannelMap() async throws {
        let avAudioUnit = try await Self.makeAVAudioUnit(Self.effectDescription)
        let inputAU = AudioUnit(bitPattern: 0xBADC0DE)!
        let stereo = SelectedChannel.stereo(
            l: AudioChannel(id: 1, name: "L"),
            r: AudioChannel(id: 2, name: "R")
        )

        let targetDevice = AudioDevice.fake()
        audioSettingsSpy.settings = .fake(inputDevice: .fake(), inputChannel: stereo)
        audioSettingsSpy.targetDevice = targetDevice
        avEngineSpy.inputAudioUnit = inputAU
        avAudioUnitFactorySpy.instantiateResult = .success(avAudioUnit)
        createSut()

        _ = try await sut.load(component: Self.effectComponent, state: nil)

        let userFormat = AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 2)
        #expect(coreAudioGatewaySpy.calls == [.setChannelMap([0, 1], 1, inputAU)])
        #expect(avEngineSpy.calls.contains(.connectHardwareInput(inputMixerSpy, userFormat)))
    }

    @Test
    mutating func load_withNonEffectAU_skipsInputConnectionEvenIfChannelSelected() async throws {
        let avAudioUnit = try await Self.makeAVAudioUnit(Self.mixerDescription)
        let inputAU = AudioUnit(bitPattern: 0xBADC0DE)!
        let stereo = SelectedChannel.stereo(
            l: AudioChannel(id: 1, name: "L"),
            r: AudioChannel(id: 2, name: "R")
        )

        let targetDevice = AudioDevice.fake()
        audioSettingsSpy.settings = .fake(inputDevice: .fake(), inputChannel: stereo)
        audioSettingsSpy.targetDevice = targetDevice
        avEngineSpy.inputAudioUnit = inputAU
        avAudioUnitFactorySpy.instantiateResult = .success(avAudioUnit)
        createSut()

        _ = try await sut.load(component: Self.mixerComponent, state: nil)

        #expect(!avEngineSpy.calls.contains { if case .connectHardwareInput = $0 { true } else { false } })
        #expect(!coreAudioGatewaySpy.calls.contains { if case .setChannelMap(_, let element, _) = $0 { element == 1 } else { false } })
    }

    @Test
    mutating func load_withStereoOutput_setsOutputChannelMap() async throws {
        let avAudioUnit = try await Self.makeAVAudioUnit(Self.effectDescription)
        let outputAU = AudioUnit(bitPattern: 0xC0FFEE)!
        let stereo = SelectedChannel.stereo(
            l: AudioChannel(id: 1, name: "L"),
            r: AudioChannel(id: 2, name: "R")
        )
        let targetDevice = AudioDevice.fake()
        audioSettingsSpy.settings = .fake(outputDevice: .fake(), outputChannel: stereo)
        audioSettingsSpy.targetDevice = targetDevice

        avEngineSpy.outputAudioUnit = outputAU
        avAudioUnitFactorySpy.instantiateResult = .success(avAudioUnit)
        coreAudioGatewaySpy.physicalChannelCountResult = 4
        createSut()

        _ = try await sut.load(component: Self.effectComponent, state: nil)

        let outputFormat = AVAudioFormat(
            standardFormatWithSampleRate: 48_000,
            channels: avAudioUnit.auAudioUnit.outputBusses[0].format.channelCount
        )
        #expect(coreAudioGatewaySpy.calls == [
            .setEnableIO(false, kAudioUnitScope_Input, 1, outputAU),
            .setEnableIO(true, kAudioUnitScope_Output, 0, outputAU),
            .setCurrentDevice(targetDevice.id, outputAU),
            .physicalChannelCount(outputAU),
            .setChannelMap([0, 1, -1, -1], 0, outputAU)
        ])
        #expect(avEngineSpy.calls.contains(.connectToMainMixer(avAudioUnit, outputFormat)))
    }

    @Test
    mutating func reload_doesNotCallFactoryOrTouchMIDI() async {
        createSut()

        try? await sut.reload()

        #expect(avAudioUnitFactorySpy.calls.isEmpty)
        #expect(midiManagerSpy.calls.isEmpty)
    }

    @Test
    mutating func reload_withoutAudioUnit_leavesEngineUntouched() async {
        createSut()

        try? await sut.reload()

        #expect(avEngineSpy.calls == [.attach(inputMixerSpy)])
    }

    @Test
    mutating func reload_withAudioUnit_rebindsAndRestarts() async throws {
        let avAudioUnit = try await Self.makeAVAudioUnit(Self.effectDescription)
        avAudioUnitFactorySpy.instantiateResult = .success(avAudioUnit)
        createSut()
        _ = try await sut.load(component: Self.effectComponent, state: nil)
        let callsAfterLoad = avEngineSpy.calls

        try await sut.reload()

        #expect(Array(avEngineSpy.calls.dropFirst(callsAfterLoad.count)) == [
            .stop,
            .disconnectMainMixerInput,
            .disconnectNodeOutput(inputMixerSpy),
            .disconnectHardwareInput,
            .start
        ])
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
