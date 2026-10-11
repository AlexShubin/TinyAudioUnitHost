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
import AudioToolboxGatewayKit
import AudioToolboxGatewayKitTestSupport
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
    var audioUnitGatewaySpy: AudioUnitGatewaySpy!
    var midiManagerSpy: MidiManagerSpy!
    var audioSettingsSpy: AudioSettingsModelSpy!
    var sut: EngineType!

    init() {
        avEngineSpy = AVAudioEngineSpy()
        inputMixerSpy = AVAudioMixerNode()
        avAudioUnitFactorySpy = AVAudioUnitFactorySpy()
        audioUnitGatewaySpy = AudioUnitGatewaySpy()
        midiManagerSpy = MidiManagerSpy()
        audioSettingsSpy = AudioSettingsModelSpy()
    }

    mutating func createSut() {
        sut = Engine(
            engine: avEngineSpy,
            inputMixer: inputMixerSpy,
            avAudioUnitFactory: avAudioUnitFactorySpy,
            audioUnitGateway: audioUnitGatewaySpy,
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
            _ = try await sut.load(component: Self.effectComponent, state: nil, at: 0)
        } catch {
            thrown = error
        }

        #expect(thrown as? EngineLoadError == .audioUnitInstantiationFailed)
        #expect(avAudioUnitFactorySpy.calls == [.instantiate(Self.effectDescription, .loadOutOfProcess)])
        #expect(midiManagerSpy.calls == [.teardownMIDI, .teardownMIDI])
        #expect(!avEngineSpy.calls.contains(.start))
    }

    @Test
    mutating func load_happyPath_attachesAU_setsUpMIDI_andStarts() async throws {
        let avAudioUnit = try await Self.makeAVAudioUnit(Self.effectDescription)
        audioSettingsSpy.setup = .met
        audioSettingsSpy.targetDevice = .fake()
        avAudioUnitFactorySpy.instantiateResult = .success(avAudioUnit)
        createSut()

        let result = try await sut.load(component: Self.effectComponent, state: nil, at: 0)

        #expect(result.component == Self.effectComponent)
        var expected: [AVAudioEngineSpy.Calls] = [.attach(inputMixerSpy)]
        expected += tearDownCalls + [.attach(avAudioUnit)]
        expected += tearDownCalls + [.start]
        #expect(avEngineSpy.calls == expected)
        #expect(midiManagerSpy.calls == [.teardownMIDI, .teardownMIDI, .setupMIDI(result)])
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
            _ = try await sut!.load(component: Self.effectComponent, state: stateAtMax, at: 0)
        }.value

        #expect(parameter.value == parameter.maxValue)
    }

    @Test
    mutating func load_replacesPreviousAU_detachesOldAndTearsDownMIDI() async throws {
        let firstAU = try await Self.makeAVAudioUnit(Self.effectDescription)
        let secondAU = try await Self.makeAVAudioUnit(Self.effectDescription)
        audioSettingsSpy.setup = .met
        audioSettingsSpy.targetDevice = .fake()
        avAudioUnitFactorySpy.instantiateResult = .success(firstAU)
        createSut()

        let firstResult = try await sut.load(component: Self.effectComponent, state: nil, at: 0)
        avAudioUnitFactorySpy.instantiateResult = .success(secondAU)

        let secondResult = try await sut.load(component: Self.effectComponent, state: nil, at: 0)

        var expected: [AVAudioEngineSpy.Calls] = [.attach(inputMixerSpy)]
        expected += tearDownCalls + [.attach(firstAU)]
        expected += tearDownCalls + [.start]
        expected += tearDownCalls + [.detach(firstAU), .attach(secondAU)]
        expected += tearDownCalls + [.start]
        #expect(avEngineSpy.calls == expected)
        #expect(midiManagerSpy.calls == [
            .teardownMIDI, .teardownMIDI, .setupMIDI(firstResult),
            .teardownMIDI, .teardownMIDI, .setupMIDI(secondResult)
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
        audioSettingsSpy.setup = .met
        audioSettingsSpy.targetDevice = targetDevice
        avEngineSpy.outputAudioUnit = outputAU
        avAudioUnitFactorySpy.instantiateResult = .success(avAudioUnit)
        createSut()

        _ = try await sut.load(component: Self.effectComponent, state: nil, at: 0)

        #expect(audioUnitGatewaySpy.calls == [
            .setEnableIO(true, .input, outputAU),
            .setEnableIO(false, .output, outputAU),
            .setCurrentDevice(targetDevice.id, outputAU)
        ])
    }

    @Test
    mutating func load_withoutTarget_keepsNodeWithoutBindingOrStarting() async throws {
        let avAudioUnit = try await Self.makeAVAudioUnit(Self.effectDescription)
        audioSettingsSpy.setup = .met
        avEngineSpy.outputAudioUnit = AudioUnit(bitPattern: 0xC0FFEE)!
        avAudioUnitFactorySpy.instantiateResult = .success(avAudioUnit)
        createSut()

        _ = try await sut.load(component: Self.effectComponent, state: nil, at: 0)

        #expect(audioUnitGatewaySpy.calls.isEmpty)
        #expect(avEngineSpy.calls.contains(.attach(avAudioUnit)))
        #expect(!avEngineSpy.calls.contains(.start))
    }

    @Test
    mutating func load_setupNotMet_keepsNodeAndMIDIWithoutBindingOrStarting() async throws {
        let avAudioUnit = try await Self.makeAVAudioUnit(Self.effectDescription)
        audioSettingsSpy.setup = .unmet([.microphonePermission])
        audioSettingsSpy.targetDevice = .fake()
        avEngineSpy.outputAudioUnit = AudioUnit(bitPattern: 0xC0FFEE)!
        avAudioUnitFactorySpy.instantiateResult = .success(avAudioUnit)
        createSut()

        let result = try await sut.load(component: Self.effectComponent, state: nil, at: 0)

        var expected: [AVAudioEngineSpy.Calls] = [.attach(inputMixerSpy)]
        expected += tearDownCalls + [.attach(avAudioUnit)]
        expected += tearDownCalls
        #expect(avEngineSpy.calls == expected)
        #expect(audioUnitGatewaySpy.calls.isEmpty)
        #expect(midiManagerSpy.calls == [.teardownMIDI, .teardownMIDI, .setupMIDI(result)])
    }

    @Test
    mutating func load_setCurrentDeviceFails_keepsNodeWithoutConnectingOrStarting() async throws {
        let avAudioUnit = try await Self.makeAVAudioUnit(Self.effectDescription)
        audioSettingsSpy.setup = .met
        audioSettingsSpy.settings = .fake(outputDevice: .fake(), outputChannel: Self.stereo)
        audioSettingsSpy.targetDevice = .fake()
        avEngineSpy.outputAudioUnit = AudioUnit(bitPattern: 0xC0FFEE)!
        audioUnitGatewaySpy.setCurrentDeviceError = AudioUnitGatewayError(operation: .setCurrentDevice, status: -1)
        avAudioUnitFactorySpy.instantiateResult = .success(avAudioUnit)
        createSut()

        let result = try await sut.load(component: Self.effectComponent, state: nil, at: 0)

        var expected: [AVAudioEngineSpy.Calls] = [.attach(inputMixerSpy)]
        expected += tearDownCalls + [.attach(avAudioUnit)]
        expected += tearDownCalls
        #expect(avEngineSpy.calls == expected)
        #expect(midiManagerSpy.calls == [.teardownMIDI, .teardownMIDI, .setupMIDI(result)])
    }

    @Test
    mutating func load_withStereoInputOnEffectAU_setsInputChannelMap() async throws {
        let avAudioUnit = try await Self.makeAVAudioUnit(Self.effectDescription)
        let inputAU = AudioUnit(bitPattern: 0xBADC0DE)!

        let targetDevice = AudioDevice.fake()
        audioSettingsSpy.settings = .fake(inputDevice: .fake(), inputChannel: Self.stereo)
        audioSettingsSpy.setup = .met
        audioSettingsSpy.targetDevice = targetDevice
        avEngineSpy.inputAudioUnit = inputAU
        avAudioUnitFactorySpy.instantiateResult = .success(avAudioUnit)
        createSut()

        _ = try await sut.load(component: Self.effectComponent, state: nil, at: 0)

        let userFormat = AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 2)
        #expect(audioUnitGatewaySpy.calls == [.setChannelMap([0, 1], .input, inputAU)])
        #expect(avEngineSpy.calls.contains(.connectHardwareInput(inputMixerSpy, userFormat)))
    }

    @Test
    mutating func load_withNonEffectAU_skipsInputConnectionEvenIfChannelSelected() async throws {
        let avAudioUnit = try await Self.makeAVAudioUnit(Self.mixerDescription)
        let inputAU = AudioUnit(bitPattern: 0xBADC0DE)!

        let targetDevice = AudioDevice.fake()
        audioSettingsSpy.settings = .fake(inputDevice: .fake(), inputChannel: Self.stereo)
        audioSettingsSpy.setup = .met
        audioSettingsSpy.targetDevice = targetDevice
        avEngineSpy.inputAudioUnit = inputAU
        avAudioUnitFactorySpy.instantiateResult = .success(avAudioUnit)
        createSut()

        _ = try await sut.load(component: Self.mixerComponent, state: nil, at: 0)

        #expect(!avEngineSpy.calls.contains { if case .connectHardwareInput = $0 { true } else { false } })
        #expect(!audioUnitGatewaySpy.calls.contains { if case .setChannelMap(_, .input, _) = $0 { true } else { false } })
    }

    @Test
    mutating func load_withStereoOutput_setsOutputChannelMap() async throws {
        let avAudioUnit = try await Self.makeAVAudioUnit(Self.effectDescription)
        let outputAU = AudioUnit(bitPattern: 0xC0FFEE)!
        let targetDevice = AudioDevice.fake()
        audioSettingsSpy.settings = .fake(outputDevice: .fake(), outputChannel: Self.stereo)
        audioSettingsSpy.setup = .met
        audioSettingsSpy.targetDevice = targetDevice

        avEngineSpy.outputAudioUnit = outputAU
        avAudioUnitFactorySpy.instantiateResult = .success(avAudioUnit)
        audioUnitGatewaySpy.physicalChannelCountResult = 4
        createSut()

        _ = try await sut.load(component: Self.effectComponent, state: nil, at: 0)

        let outputFormat = AVAudioFormat(
            standardFormatWithSampleRate: 48_000,
            channels: avAudioUnit.auAudioUnit.outputBusses[0].format.channelCount
        )
        #expect(audioUnitGatewaySpy.calls == [
            .setEnableIO(false, .input, outputAU),
            .setEnableIO(true, .output, outputAU),
            .setCurrentDevice(targetDevice.id, outputAU),
            .physicalChannelCount(outputAU),
            .setChannelMap([0, 1, -1, -1], .output, outputAU)
        ])
        #expect(avEngineSpy.calls.contains(.connectToMainMixer(avAudioUnit, outputFormat)))
    }

    // MARK: - chain

    @Test
    mutating func load_secondPosition_connectsFirstIntoSecondAndSecondToOutput() async throws {
        let first = try await Self.makeAVAudioUnit(Self.effectDescription)
        let second = try await Self.makeAVAudioUnit(Self.effectDescription)
        audioSettingsSpy.settings = .fake(outputDevice: .fake(), outputChannel: Self.stereo)
        audioSettingsSpy.setup = .met
        audioSettingsSpy.targetDevice = .fake()
        avAudioUnitFactorySpy.instantiateResult = .success(first)
        createSut()
        _ = try await sut.load(component: Self.effectComponent, state: nil, at: 0)
        avAudioUnitFactorySpy.instantiateResult = .success(second)
        let callsBefore = avEngineSpy.calls.count

        _ = try await sut.load(component: Self.effectComponent, state: nil, at: 1)

        let calls = Array(avEngineSpy.calls.dropFirst(callsBefore))
        #expect(calls.contains(.connect(first, second, Self.outputFormat(of: first))))
        #expect(calls.contains(.connectToMainMixer(second, Self.outputFormat(of: second))))
        #expect(!calls.contains(.detach(first)))
    }

    @Test
    mutating func load_lowerPositionAfterHigher_ordersChainByPosition() async throws {
        let upper = try await Self.makeAVAudioUnit(Self.effectDescription)
        let lower = try await Self.makeAVAudioUnit(Self.effectDescription)
        audioSettingsSpy.settings = .fake(outputDevice: .fake(), outputChannel: Self.stereo)
        audioSettingsSpy.setup = .met
        audioSettingsSpy.targetDevice = .fake()
        avAudioUnitFactorySpy.instantiateResult = .success(upper)
        createSut()
        _ = try await sut.load(component: Self.effectComponent, state: nil, at: 2)
        avAudioUnitFactorySpy.instantiateResult = .success(lower)
        let callsBefore = avEngineSpy.calls.count

        _ = try await sut.load(component: Self.effectComponent, state: nil, at: 1)

        let calls = Array(avEngineSpy.calls.dropFirst(callsBefore))
        #expect(calls.contains(.connect(lower, upper, Self.outputFormat(of: lower))))
        #expect(calls.contains(.connectToMainMixer(upper, Self.outputFormat(of: upper))))
    }

    @Test
    mutating func load_occupiedPosition_detachesOnlyThatNode() async throws {
        let first = try await Self.makeAVAudioUnit(Self.effectDescription)
        let second = try await Self.makeAVAudioUnit(Self.effectDescription)
        let replacement = try await Self.makeAVAudioUnit(Self.effectDescription)
        audioSettingsSpy.setup = .met
        audioSettingsSpy.targetDevice = .fake()
        avAudioUnitFactorySpy.instantiateResult = .success(first)
        createSut()
        _ = try await sut.load(component: Self.effectComponent, state: nil, at: 0)
        avAudioUnitFactorySpy.instantiateResult = .success(second)
        _ = try await sut.load(component: Self.effectComponent, state: nil, at: 1)
        avAudioUnitFactorySpy.instantiateResult = .success(replacement)
        let callsBefore = avEngineSpy.calls.count

        _ = try await sut.load(component: Self.effectComponent, state: nil, at: 1)

        let calls = Array(avEngineSpy.calls.dropFirst(callsBefore))
        #expect(calls.contains(.detach(second)))
        #expect(!calls.contains(.detach(first)))
        #expect(calls.contains(.connect(first, replacement, Self.outputFormat(of: first))))
    }

    @Test
    mutating func load_secondPosition_setsUpMIDIForFirstNode() async throws {
        let first = try await Self.makeAVAudioUnit(Self.effectDescription)
        let second = try await Self.makeAVAudioUnit(Self.effectDescription)
        avAudioUnitFactorySpy.instantiateResult = .success(first)
        createSut()
        let firstLoaded = try await sut.load(component: Self.effectComponent, state: nil, at: 0)
        avAudioUnitFactorySpy.instantiateResult = .success(second)

        _ = try await sut.load(component: Self.effectComponent, state: nil, at: 1)

        #expect(midiManagerSpy.calls == [
            .teardownMIDI, .teardownMIDI, .setupMIDI(firstLoaded),
            .teardownMIDI, .teardownMIDI, .setupMIDI(firstLoaded)
        ])
    }

    @Test
    mutating func load_factoryFailure_restartsRemainingChain() async throws {
        let first = try await Self.makeAVAudioUnit(Self.effectDescription)
        audioSettingsSpy.setup = .met
        audioSettingsSpy.targetDevice = .fake()
        avAudioUnitFactorySpy.instantiateResult = .success(first)
        createSut()
        let firstLoaded = try await sut.load(component: Self.effectComponent, state: nil, at: 0)
        avAudioUnitFactorySpy.instantiateResult = .failure(TestError.factoryFailed)
        let callsBefore = avEngineSpy.calls.count

        var thrown: EngineLoadError?
        do {
            _ = try await sut.load(component: Self.effectComponent, state: nil, at: 1)
        } catch {
            thrown = error
        }

        #expect(thrown == .audioUnitInstantiationFailed)
        #expect(Array(avEngineSpy.calls.dropFirst(callsBefore)).contains(.start))
        #expect(midiManagerSpy.calls.last == .setupMIDI(firstLoaded))
    }

    @Test
    mutating func load_factoryFailureAtOccupiedPosition_clearsItAndStaysStopped() async throws {
        let first = try await Self.makeAVAudioUnit(Self.effectDescription)
        audioSettingsSpy.setup = .met
        audioSettingsSpy.targetDevice = .fake()
        avAudioUnitFactorySpy.instantiateResult = .success(first)
        createSut()
        _ = try await sut.load(component: Self.effectComponent, state: nil, at: 0)
        avAudioUnitFactorySpy.instantiateResult = .failure(TestError.factoryFailed)
        let callsBefore = avEngineSpy.calls.count

        _ = try? await sut.load(component: Self.effectComponent, state: nil, at: 0)

        let calls = Array(avEngineSpy.calls.dropFirst(callsBefore))
        #expect(calls.contains(.detach(first)))
        #expect(!calls.contains(.start))
    }

    @Test
    mutating func load_whileAnotherLoadInstantiates_endsWithBothNodesWired() async throws {
        let first = try await Self.makeAVAudioUnit(Self.effectDescription)
        let second = try await Self.makeAVAudioUnit(Self.effectDescription)
        audioSettingsSpy.setup = .met
        audioSettingsSpy.targetDevice = .fake()
        avAudioUnitFactorySpy.instantiateResult = .success(first)
        createSut()
        let engine = sut!
        let factory = avAudioUnitFactorySpy!
        factory.onInstantiate = {
            factory.onInstantiate = nil
            factory.instantiateResult = .success(second)
            _ = try? await engine.load(component: Self.effectComponent, state: nil, at: 1)
            factory.instantiateResult = .success(first)
        }

        let firstLoaded = try await sut.load(component: Self.effectComponent, state: nil, at: 0)

        let lastRebuild = avEngineSpy.calls.suffix(from: try #require(avEngineSpy.calls.lastIndex(of: .stop)))
        #expect(lastRebuild.contains(.connect(first, second, Self.outputFormat(of: first))))
        #expect(avEngineSpy.calls.last == .start)
        #expect(midiManagerSpy.calls.suffix(2) == [.teardownMIDI, .setupMIDI(firstLoaded)])
    }

    @Test
    mutating func unload_middlePosition_connectsNeighbours() async throws {
        let first = try await Self.makeAVAudioUnit(Self.effectDescription)
        let middle = try await Self.makeAVAudioUnit(Self.effectDescription)
        let last = try await Self.makeAVAudioUnit(Self.effectDescription)
        audioSettingsSpy.setup = .met
        audioSettingsSpy.targetDevice = .fake()
        avAudioUnitFactorySpy.instantiateResult = .success(first)
        createSut()
        _ = try await sut.load(component: Self.effectComponent, state: nil, at: 0)
        avAudioUnitFactorySpy.instantiateResult = .success(middle)
        _ = try await sut.load(component: Self.effectComponent, state: nil, at: 1)
        avAudioUnitFactorySpy.instantiateResult = .success(last)
        _ = try await sut.load(component: Self.effectComponent, state: nil, at: 2)
        let callsBefore = avEngineSpy.calls.count

        await sut.unload(at: 1)

        let calls = Array(avEngineSpy.calls.dropFirst(callsBefore))
        #expect(calls.contains(.detach(middle)))
        #expect(calls.contains(.connect(first, last, Self.outputFormat(of: first))))
        #expect(calls.contains(.start))
    }

    @Test
    mutating func unload_withAudioUnit_stopsDisconnectsAndDetaches() async throws {
        let avAudioUnit = try await Self.makeAVAudioUnit(Self.effectDescription)
        avAudioUnitFactorySpy.instantiateResult = .success(avAudioUnit)
        createSut()
        let loaded = try await sut.load(component: Self.effectComponent, state: nil, at: 0)
        let callsAfterLoad = avEngineSpy.calls

        await sut.unload(at: 0)

        let expected: [AVAudioEngineSpy.Calls] = tearDownCalls + [.detach(avAudioUnit)] + tearDownCalls
        #expect(Array(avEngineSpy.calls.dropFirst(callsAfterLoad.count)) == expected)
        #expect(midiManagerSpy.calls == [.teardownMIDI, .teardownMIDI, .setupMIDI(loaded), .teardownMIDI, .teardownMIDI])
    }

    @Test
    mutating func unload_withoutAudioUnit_stopsAndDisconnectsWithoutDetach() async {
        createSut()

        await sut.unload(at: 0)

        let expected: [AVAudioEngineSpy.Calls] = [.attach(inputMixerSpy)] + tearDownCalls + tearDownCalls
        #expect(avEngineSpy.calls == expected)
        #expect(midiManagerSpy.calls == [.teardownMIDI, .teardownMIDI])
    }

    @Test
    mutating func unload_thenReload_leavesEngineUntouched() async throws {
        let avAudioUnit = try await Self.makeAVAudioUnit(Self.effectDescription)
        avAudioUnitFactorySpy.instantiateResult = .success(avAudioUnit)
        createSut()
        _ = try await sut.load(component: Self.effectComponent, state: nil, at: 0)
        await sut.unload(at: 0)
        let callsAfterUnload = avEngineSpy.calls

        await sut.reload()

        #expect(avEngineSpy.calls == callsAfterUnload)
    }

    @Test
    mutating func reload_doesNotCallFactoryOrTouchMIDI() async {
        createSut()

        await sut.reload()

        #expect(avAudioUnitFactorySpy.calls.isEmpty)
        #expect(midiManagerSpy.calls.isEmpty)
    }

    @Test
    mutating func reload_withoutAudioUnit_leavesEngineUntouched() async {
        createSut()

        await sut.reload()

        #expect(avEngineSpy.calls == [.attach(inputMixerSpy)])
    }

    @Test
    mutating func reload_withAudioUnit_rebindsAndRestarts() async throws {
        let avAudioUnit = try await Self.makeAVAudioUnit(Self.effectDescription)
        audioSettingsSpy.setup = .met
        audioSettingsSpy.targetDevice = .fake()
        avAudioUnitFactorySpy.instantiateResult = .success(avAudioUnit)
        createSut()
        _ = try await sut.load(component: Self.effectComponent, state: nil, at: 0)
        let callsAfterLoad = avEngineSpy.calls

        await sut.reload()

        #expect(Array(avEngineSpy.calls.dropFirst(callsAfterLoad.count)) == [
            .stop,
            .disconnectMainMixerInput,
            .disconnectNodeOutput(inputMixerSpy),
            .disconnectHardwareInput,
            .start
        ])
    }

    @Test
    mutating func reload_setupMetAfterLoadingUnmet_startsChain() async throws {
        let avAudioUnit = try await Self.makeAVAudioUnit(Self.effectDescription)
        audioSettingsSpy.setup = .unmet([.microphonePermission])
        audioSettingsSpy.targetDevice = .fake()
        avAudioUnitFactorySpy.instantiateResult = .success(avAudioUnit)
        createSut()
        _ = try await sut.load(component: Self.effectComponent, state: nil, at: 0)
        audioSettingsSpy.setup = .met
        let callsAfterLoad = avEngineSpy.calls

        await sut.reload()

        #expect(Array(avEngineSpy.calls.dropFirst(callsAfterLoad.count)) == tearDownCalls + [.start])
    }

    @Test
    mutating func reload_setupNoLongerMet_stopsWithoutRestarting() async throws {
        let avAudioUnit = try await Self.makeAVAudioUnit(Self.effectDescription)
        audioSettingsSpy.setup = .met
        audioSettingsSpy.targetDevice = .fake()
        avAudioUnitFactorySpy.instantiateResult = .success(avAudioUnit)
        createSut()
        _ = try await sut.load(component: Self.effectComponent, state: nil, at: 0)
        audioSettingsSpy.setup = .unmet([.noOutputDevice])
        let callsAfterLoad = avEngineSpy.calls

        await sut.reload()

        #expect(Array(avEngineSpy.calls.dropFirst(callsAfterLoad.count)) == tearDownCalls)
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
        AudioUnitComponent(id: effectDescription.componentID, name: "Dyn", manufacturer: "Apple")
    }

    static var mixerComponent: AudioUnitComponent {
        AudioUnitComponent(id: mixerDescription.componentID, name: "Mix", manufacturer: "Apple")
    }

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

    var tearDownCalls: [AVAudioEngineSpy.Calls] {
        [.stop, .disconnectMainMixerInput, .disconnectNodeOutput(inputMixerSpy), .disconnectHardwareInput]
    }

    static func makeAVAudioUnit(_ desc: AudioComponentDescription) async throws -> AVAudioUnit {
        try await AVAudioUnit.instantiate(with: desc, options: [])
    }
}

private extension AudioComponentDescription {
    var componentID: AudioUnitComponent.ID {
        AudioUnitComponent.ID(type: componentType, subType: componentSubType, manufacturer: componentManufacturer)
    }
}
