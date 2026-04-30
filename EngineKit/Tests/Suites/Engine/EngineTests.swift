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
    @Test
    func init_attachesInputMixer() async {
        let sut = makeSut()

        #expect(sut.avEngine.calls.count == 1)
        if case .attach(let node) = sut.avEngine.calls.first {
            #expect(node is AVAudioMixerNode)
        } else {
            Issue.record("expected attach call")
        }
    }

    @Test
    func load_factoryFailure_returnsNilAndShortCircuits() async {
        let sut = makeSut(factoryResult: .failure(TestError.factoryFailed))

        let result = await sut.engine.load(component: Self.effectComponent)

        #expect(result == nil)
        #expect(sut.midi.calls == [.teardownMIDI])
        #expect(sut.factory.calls == [.instantiate(Self.effectDescription, .loadOutOfProcess)])
        #expect(!sut.avEngine.calls.contains(.start))
        #expect(sut.avEngine.calls.allSatisfy {
            if case .attach(let node) = $0 { return node is AVAudioMixerNode }
            return true
        })
    }

    @Test
    func load_happyPath_attachesAU_setsUpMIDI_andStarts() async throws {
        let avAudioUnit = try await Self.makeAVAudioUnit(Self.effectDescription)
        let sut = makeSut(factoryResult: .success(avAudioUnit))

        let result = await sut.engine.load(component: Self.effectComponent)

        #expect(result?.component == Self.effectComponent)

        let attachIndex = try #require(sut.avEngine.calls.firstIndex { $0 == .attach(avAudioUnit) })
        let startIndex = try #require(sut.avEngine.calls.firstIndex { $0 == .start })
        #expect(attachIndex < startIndex)

        #expect(sut.midi.calls == [.teardownMIDI, .setupMIDI(avAudioUnit.auAudioUnit)])
    }

    @Test
    func load_replacesPreviousAU_detachesOldAndTearsDownMIDI() async throws {
        let firstAU = try await Self.makeAVAudioUnit(Self.effectDescription)
        let secondAU = try await Self.makeAVAudioUnit(Self.effectDescription)
        let sut = makeSut(factoryResult: .success(firstAU))

        _ = await sut.engine.load(component: Self.effectComponent)
        sut.factory.instantiateResult = .success(secondAU)

        _ = await sut.engine.load(component: Self.effectComponent)

        #expect(sut.avEngine.calls.contains(.detach(firstAU)))
        #expect(sut.midi.calls.filter { $0 == .teardownMIDI }.count == 2)
        #expect(sut.midi.calls.contains(.setupMIDI(secondAU.auAudioUnit)))
    }

    @Test
    func load_withTarget_bindsDeviceAndSetsBuffer() async throws {
        let avAudioUnit = try await Self.makeAVAudioUnit(Self.effectDescription)
        let outputAU = AudioUnit(bitPattern: 0xC0FFEE)!
        let sut = makeSut(
            factoryResult: .success(avAudioUnit),
            settings: AudioSettings(input: .empty, output: .empty, bufferSize: 256),
            target: Self.makeTarget(),
            outputAudioUnit: outputAU
        )

        _ = await sut.engine.load(component: Self.effectComponent)

        #expect(sut.gateway.calls.contains(.setEnableIO(true, kAudioUnitScope_Input, 1, outputAU)))
        #expect(sut.gateway.calls.contains(.setEnableIO(true, kAudioUnitScope_Output, 0, outputAU)))
        #expect(sut.gateway.calls.contains(.setCurrentDevice(Self.deviceID, outputAU)))
        #expect(sut.gateway.calls.contains(.setBufferSize(256, Self.deviceID)))
    }

    @Test
    func load_withTargetButNoBufferSize_skipsBuffer() async throws {
        let avAudioUnit = try await Self.makeAVAudioUnit(Self.effectDescription)
        let outputAU = AudioUnit(bitPattern: 0xC0FFEE)!
        let sut = makeSut(
            factoryResult: .success(avAudioUnit),
            settings: .empty,
            target: Self.makeTarget(),
            outputAudioUnit: outputAU
        )

        _ = await sut.engine.load(component: Self.effectComponent)

        #expect(!sut.gateway.calls.contains { if case .setBufferSize = $0 { true } else { false } })
    }

    @Test
    func load_withoutTarget_skipsDeviceBindingAndBuffer() async throws {
        let avAudioUnit = try await Self.makeAVAudioUnit(Self.effectDescription)
        let outputAU = AudioUnit(bitPattern: 0xC0FFEE)!
        let sut = makeSut(
            factoryResult: .success(avAudioUnit),
            settings: AudioSettings(input: .empty, output: .empty, bufferSize: 256),
            target: nil,
            outputAudioUnit: outputAU
        )

        _ = await sut.engine.load(component: Self.effectComponent)

        #expect(!sut.gateway.calls.contains { if case .setEnableIO = $0 { true } else { false } })
        #expect(!sut.gateway.calls.contains { if case .setCurrentDevice = $0 { true } else { false } })
        #expect(!sut.gateway.calls.contains { if case .setBufferSize = $0 { true } else { false } })
    }

    @Test
    func load_withStereoInputOnEffectAU_setsInputChannelMap() async throws {
        let avAudioUnit = try await Self.makeAVAudioUnit(Self.effectDescription)
        let inputAU = AudioUnit(bitPattern: 0xBADC0DE)!
        let stereo = SelectedChannel.stereo(
            l: AudioChannel(id: 1, name: "L"),
            r: AudioChannel(id: 2, name: "R")
        )
        let sut = makeSut(
            factoryResult: .success(avAudioUnit),
            settings: AudioSettings(
                input: DeviceSettings(device: nil, selectedChannel: stereo),
                output: .empty
            ),
            target: Self.makeTarget(inputOffset: 2),
            inputAudioUnit: inputAU
        )

        _ = await sut.engine.load(component: Self.effectComponent)

        #expect(sut.gateway.calls.contains(.setChannelMap([2, 3], 1, inputAU)))
        #expect(sut.avEngine.calls.contains { call in
            if case .connectHardwareInput(let node, _) = call { node is AVAudioMixerNode } else { false }
        })
    }

    @Test
    func load_withNonEffectAU_skipsInputConnectionEvenIfChannelSelected() async throws {
        let avAudioUnit = try await Self.makeAVAudioUnit(Self.mixerDescription)
        let inputAU = AudioUnit(bitPattern: 0xBADC0DE)!
        let stereo = SelectedChannel.stereo(
            l: AudioChannel(id: 1, name: "L"),
            r: AudioChannel(id: 2, name: "R")
        )
        let sut = makeSut(
            factoryResult: .success(avAudioUnit),
            settings: AudioSettings(
                input: DeviceSettings(device: nil, selectedChannel: stereo),
                output: .empty
            ),
            target: Self.makeTarget(),
            inputAudioUnit: inputAU
        )

        _ = await sut.engine.load(component: Self.mixerComponent)

        #expect(!sut.avEngine.calls.contains { call in
            if case .connectHardwareInput = call { true } else { false }
        })
        #expect(!sut.gateway.calls.contains { call in
            if case .setChannelMap(_, let element, _) = call { element == 1 } else { false }
        })
    }

    @Test
    func load_withStereoOutput_setsOutputChannelMap() async throws {
        let avAudioUnit = try await Self.makeAVAudioUnit(Self.effectDescription)
        let outputAU = AudioUnit(bitPattern: 0xC0FFEE)!
        let stereo = SelectedChannel.stereo(
            l: AudioChannel(id: 1, name: "L"),
            r: AudioChannel(id: 2, name: "R")
        )
        let sut = makeSut(
            factoryResult: .success(avAudioUnit),
            settings: AudioSettings(
                input: .empty,
                output: DeviceSettings(device: nil, selectedChannel: stereo)
            ),
            target: Self.makeTarget(),
            outputAudioUnit: outputAU,
            physicalChannelCount: 4
        )

        _ = await sut.engine.load(component: Self.effectComponent)

        #expect(sut.gateway.calls.contains(.setChannelMap([0, 1, -1, -1], 0, outputAU)))
        #expect(sut.avEngine.calls.contains { call in
            if case .connectToMainMixer(let node, _) = call { node === avAudioUnit } else { false }
        })
    }

    @Test
    func reload_doesNotCallFactoryOrTouchMIDI() async {
        let sut = makeSut()
        let midiCallsBefore = sut.midi.calls

        await sut.engine.reload()

        #expect(sut.factory.calls.isEmpty)
        #expect(sut.midi.calls == midiCallsBefore)
        #expect(sut.avEngine.calls.contains(.stop))
        #expect(sut.avEngine.calls.contains(.start))
        #expect(sut.avEngine.calls.contains(.disconnectMainMixerInput))
        #expect(sut.avEngine.calls.contains(.disconnectHardwareInput))
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

    struct Sut {
        let engine: Engine
        let avEngine: AVAudioEngineMock
        let factory: AVAudioUnitFactoryMock
        let gateway: CoreAudioGatewayMock
        let midi: CoreMidiManagerMock
        let settings: AudioSettingsStoreMock
        let aggregate: AggregateDeviceManagerMock
    }

    func makeSut(
        factoryResult: Result<AVAudioUnit, Error>? = nil,
        settings: AudioSettings = .empty,
        target: TargetAudioDevice? = nil,
        inputAudioUnit: AudioUnit? = nil,
        outputAudioUnit: AudioUnit? = nil,
        physicalChannelCount: Int? = nil
    ) -> Sut {
        let avEngine = AVAudioEngineMock(
            inputAudioUnit: inputAudioUnit,
            outputAudioUnit: outputAudioUnit
        )
        let factory = AVAudioUnitFactoryMock(instantiateResult: factoryResult)
        let gateway = CoreAudioGatewayMock(physicalChannelCountResult: physicalChannelCount)
        let midi = CoreMidiManagerMock()
        let settingsStore = AudioSettingsStoreMock(settings: settings)
        let aggregate = AggregateDeviceManagerMock(resolveTargetResult: target)

        let engine = Engine(
            engine: avEngine,
            inputMixer: AVAudioMixerNode(),
            avAudioUnitFactory: factory,
            coreAudioGateway: gateway,
            coreMidiManager: midi,
            settingsStore: settingsStore,
            aggregateDeviceManager: aggregate
        )

        return Sut(
            engine: engine,
            avEngine: avEngine,
            factory: factory,
            gateway: gateway,
            midi: midi,
            settings: settingsStore,
            aggregate: aggregate
        )
    }
}
