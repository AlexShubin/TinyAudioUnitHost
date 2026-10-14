//
//  PluginChainTests.swift
//  EngineKitTests
//
//  Created by Alex Shubin on 30.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioToolbox
import AudioUnitsKit
import AVFoundation
import EngineKitTestSupport
import Testing
@testable import EngineKit

@Suite @MainActor
struct PluginChainTests {
    var avEngineSpy: AVAudioEngineSpy!
    var avAudioUnitFactorySpy: AVAudioUnitFactorySpy!
    var hardwareConnectorSpy: HardwareConnectorSpy!
    var midiManagerSpy: MidiManagerSpy!
    var sut: PluginChainType!

    init() {
        avEngineSpy = AVAudioEngineSpy()
        avAudioUnitFactorySpy = AVAudioUnitFactorySpy()
        hardwareConnectorSpy = HardwareConnectorSpy()
        midiManagerSpy = MidiManagerSpy()
    }

    mutating func createSut() {
        sut = PluginChain(
            engine: avEngineSpy,
            avAudioUnitFactory: avAudioUnitFactorySpy,
            hardwareConnector: hardwareConnectorSpy,
            midiManager: midiManagerSpy
        )
    }

    // MARK: - load

    @Test
    mutating func load_factoryFailure_throwsAndShortCircuits() async {
        avAudioUnitFactorySpy.instantiateResult = .failure(TestError.factoryFailed)
        createSut()

        var thrown: Error?
        do {
            _ = try await sut.load(.fake(component: Self.effectComponent), at: 0)
        } catch {
            thrown = error
        }

        #expect(thrown as? PluginChainLoadError == .audioUnitInstantiationFailed)
        #expect(avAudioUnitFactorySpy.calls == [.instantiate(Self.effectDescription, .loadOutOfProcess)])
        #expect(hardwareConnectorSpy.calls == [.disconnect, .disconnect])
        #expect(midiManagerSpy.calls == [.teardownMIDI, .teardownMIDI])
        #expect(!avEngineSpy.calls.contains(.start))
    }

    @Test
    mutating func load_happyPath_attachesConnectsStartsAndSetsUpMIDI() async throws {
        let avAudioUnit = try await Self.makeAVAudioUnit(Self.effectDescription)
        avAudioUnitFactorySpy.instantiateResult = .success(avAudioUnit)
        createSut()

        let result = try await sut.load(.fake(component: Self.effectComponent), at: 0)

        #expect(result.component == Self.effectComponent)
        #expect(avEngineSpy.calls == [.stop, .attach(avAudioUnit), .stop, .start])
        #expect(hardwareConnectorSpy.calls == [.disconnect, .disconnect, .connect(first: avAudioUnit, last: avAudioUnit)])
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
            _ = try await sut!.load(.fake(component: Self.effectComponent, state: stateAtMax), at: 0)
        }.value

        #expect(parameter.value == parameter.maxValue)
    }

    @Test
    mutating func load_replacesPreviousAU_detachesOldAndTearsDownMIDI() async throws {
        let firstAU = try await Self.makeAVAudioUnit(Self.effectDescription)
        let secondAU = try await Self.makeAVAudioUnit(Self.effectDescription)
        avAudioUnitFactorySpy.instantiateResult = .success(firstAU)
        createSut()

        let firstResult = try await sut.load(.fake(component: Self.effectComponent), at: 0)
        avAudioUnitFactorySpy.instantiateResult = .success(secondAU)

        let secondResult = try await sut.load(.fake(component: Self.effectComponent), at: 0)

        #expect(avEngineSpy.calls == [
            .stop, .attach(firstAU), .stop, .start,
            .stop, .detach(firstAU), .attach(secondAU), .stop, .start
        ])
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
    mutating func load_hardwareNotConnected_keepsNodeWithoutStartingOrMIDI() async throws {
        let avAudioUnit = try await Self.makeAVAudioUnit(Self.effectDescription)
        avAudioUnitFactorySpy.instantiateResult = .success(avAudioUnit)
        hardwareConnectorSpy.connectResult = false
        createSut()

        _ = try await sut.load(.fake(component: Self.effectComponent), at: 0)

        #expect(avEngineSpy.calls == [.stop, .attach(avAudioUnit), .stop])
        #expect(midiManagerSpy.calls == [.teardownMIDI, .teardownMIDI])
    }

    // MARK: - load slots

    @Test
    mutating func loadSlots_attachesEachSlotAndStartsOnce() async throws {
        let first = try await Self.makeAVAudioUnit(Self.effectDescription)
        let second = try await Self.makeAVAudioUnit(Self.delayDescription)
        avAudioUnitFactorySpy.instantiateResultByDescription = [
            Self.effectDescription: .success(first),
            Self.delayDescription: .success(second),
        ]
        createSut()

        let results = await sut.load([.fake(component: Self.effectComponent), .fake(component: Self.delayComponent)])

        #expect(results.map(\.?.component) == [Self.effectComponent, Self.delayComponent])
        #expect(avEngineSpy.calls.contains(.attach(first)))
        #expect(avEngineSpy.calls.contains(.attach(second)))
        #expect(avEngineSpy.calls.contains(.connect(first, second, Self.outputFormat(of: first))))
        #expect(hardwareConnectorSpy.calls.last == .connect(first: first, last: second))
        #expect(avEngineSpy.calls.filter { $0 == .start } == [.start])
        #expect(avEngineSpy.calls.last == .start)
    }

    @Test
    mutating func loadSlots_setsUpMIDIForFirstSlotOnce() async throws {
        let first = try await Self.makeAVAudioUnit(Self.effectDescription)
        let second = try await Self.makeAVAudioUnit(Self.delayDescription)
        avAudioUnitFactorySpy.instantiateResultByDescription = [
            Self.effectDescription: .success(first),
            Self.delayDescription: .success(second),
        ]
        createSut()

        let results = await sut.load([.fake(component: Self.effectComponent), .fake(component: Self.delayComponent)])

        let firstLoaded = try #require(try results[0]?.get())
        #expect(midiManagerSpy.calls == [.teardownMIDI, .teardownMIDI, .setupMIDI(firstLoaded)])
    }

    @Test
    mutating func loadSlots_gap_returnsNilAndConnectsAcrossIt() async throws {
        let first = try await Self.makeAVAudioUnit(Self.effectDescription)
        let third = try await Self.makeAVAudioUnit(Self.delayDescription)
        avAudioUnitFactorySpy.instantiateResultByDescription = [
            Self.effectDescription: .success(first),
            Self.delayDescription: .success(third),
        ]
        createSut()

        let results = await sut.load([.fake(component: Self.effectComponent), nil, .fake(component: Self.delayComponent)])

        #expect(results.map(\.?.component) == [Self.effectComponent, nil, Self.delayComponent])
        #expect(avAudioUnitFactorySpy.calls.count == 2)
        #expect(avEngineSpy.calls.contains(.connect(first, third, Self.outputFormat(of: first))))
    }

    @Test
    mutating func loadSlots_oneFails_returnsFailureAndStartsTheRest() async throws {
        let first = try await Self.makeAVAudioUnit(Self.effectDescription)
        avAudioUnitFactorySpy.instantiateResultByDescription = [Self.effectDescription: .success(first)]
        createSut()

        let results = await sut.load([.fake(component: Self.effectComponent), .fake(component: Self.delayComponent)])

        #expect(results.map(\.?.component) == [Self.effectComponent, nil])
        #expect(results[1] == .failure(.audioUnitInstantiationFailed))
        #expect(avEngineSpy.calls.contains(.attach(first)))
        #expect(avEngineSpy.calls.last == .start)
    }

    @Test
    mutating func loadSlots_existingChain_detachesEveryOldNode() async throws {
        let old = try await Self.makeAVAudioUnit(Self.effectDescription)
        let oldInsert = try await Self.makeAVAudioUnit(Self.effectDescription)
        let new = try await Self.makeAVAudioUnit(Self.delayDescription)
        avAudioUnitFactorySpy.instantiateResult = .success(old)
        createSut()
        _ = try await sut.load(.fake(component: Self.effectComponent), at: 0)
        avAudioUnitFactorySpy.instantiateResult = .success(oldInsert)
        _ = try await sut.load(.fake(component: Self.effectComponent), at: 3)
        avAudioUnitFactorySpy.instantiateResult = .success(new)
        let callsBefore = avEngineSpy.calls.count

        _ = await sut.load([.fake(component: Self.delayComponent)])

        let calls = Array(avEngineSpy.calls.dropFirst(callsBefore))
        #expect(calls.contains(.detach(old)))
        #expect(calls.contains(.detach(oldInsert)))
        #expect(calls.contains(.attach(new)))
        #expect(!calls.contains { if case .connect = $0 { true } else { false } })
        #expect(calls.last == .start)
    }

    @Test
    mutating func loadSlots_empty_detachesChainAndStaysStopped() async throws {
        let old = try await Self.makeAVAudioUnit(Self.effectDescription)
        avAudioUnitFactorySpy.instantiateResult = .success(old)
        createSut()
        _ = try await sut.load(.fake(component: Self.effectComponent), at: 0)
        let callsBefore = avEngineSpy.calls.count

        let results = await sut.load([])

        #expect(results.isEmpty)
        #expect(Array(avEngineSpy.calls.dropFirst(callsBefore)) == [.stop, .detach(old), .stop])
    }

    // MARK: - chain

    @Test
    mutating func load_secondPosition_linksFirstIntoSecondAndConnectsChainEnds() async throws {
        let first = try await Self.makeAVAudioUnit(Self.effectDescription)
        let second = try await Self.makeAVAudioUnit(Self.effectDescription)
        avAudioUnitFactorySpy.instantiateResult = .success(first)
        createSut()
        _ = try await sut.load(.fake(component: Self.effectComponent), at: 0)
        avAudioUnitFactorySpy.instantiateResult = .success(second)
        let callsBefore = avEngineSpy.calls.count

        _ = try await sut.load(.fake(component: Self.effectComponent), at: 1)

        let calls = Array(avEngineSpy.calls.dropFirst(callsBefore))
        #expect(calls.contains(.connect(first, second, Self.outputFormat(of: first))))
        #expect(hardwareConnectorSpy.calls.last == .connect(first: first, last: second))
        #expect(!calls.contains(.detach(first)))
    }

    @Test
    mutating func load_lowerPositionAfterHigher_ordersChainByPosition() async throws {
        let upper = try await Self.makeAVAudioUnit(Self.effectDescription)
        let lower = try await Self.makeAVAudioUnit(Self.effectDescription)
        avAudioUnitFactorySpy.instantiateResult = .success(upper)
        createSut()
        _ = try await sut.load(.fake(component: Self.effectComponent), at: 2)
        avAudioUnitFactorySpy.instantiateResult = .success(lower)
        let callsBefore = avEngineSpy.calls.count

        _ = try await sut.load(.fake(component: Self.effectComponent), at: 1)

        let calls = Array(avEngineSpy.calls.dropFirst(callsBefore))
        #expect(calls.contains(.connect(lower, upper, Self.outputFormat(of: lower))))
        #expect(hardwareConnectorSpy.calls.last == .connect(first: lower, last: upper))
    }

    @Test
    mutating func load_occupiedPosition_detachesOnlyThatNode() async throws {
        let first = try await Self.makeAVAudioUnit(Self.effectDescription)
        let second = try await Self.makeAVAudioUnit(Self.effectDescription)
        let replacement = try await Self.makeAVAudioUnit(Self.effectDescription)
        avAudioUnitFactorySpy.instantiateResult = .success(first)
        createSut()
        _ = try await sut.load(.fake(component: Self.effectComponent), at: 0)
        avAudioUnitFactorySpy.instantiateResult = .success(second)
        _ = try await sut.load(.fake(component: Self.effectComponent), at: 1)
        avAudioUnitFactorySpy.instantiateResult = .success(replacement)
        let callsBefore = avEngineSpy.calls.count

        _ = try await sut.load(.fake(component: Self.effectComponent), at: 1)

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
        let firstLoaded = try await sut.load(.fake(component: Self.effectComponent), at: 0)
        avAudioUnitFactorySpy.instantiateResult = .success(second)

        _ = try await sut.load(.fake(component: Self.effectComponent), at: 1)

        #expect(midiManagerSpy.calls == [
            .teardownMIDI, .teardownMIDI, .setupMIDI(firstLoaded),
            .teardownMIDI, .teardownMIDI, .setupMIDI(firstLoaded)
        ])
    }

    @Test
    mutating func load_factoryFailure_restartsRemainingChain() async throws {
        let first = try await Self.makeAVAudioUnit(Self.effectDescription)
        avAudioUnitFactorySpy.instantiateResult = .success(first)
        createSut()
        let firstLoaded = try await sut.load(.fake(component: Self.effectComponent), at: 0)
        avAudioUnitFactorySpy.instantiateResult = .failure(TestError.factoryFailed)
        let callsBefore = avEngineSpy.calls.count

        var thrown: PluginChainLoadError?
        do {
            _ = try await sut.load(.fake(component: Self.effectComponent), at: 1)
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
        avAudioUnitFactorySpy.instantiateResult = .success(first)
        createSut()
        _ = try await sut.load(.fake(component: Self.effectComponent), at: 0)
        avAudioUnitFactorySpy.instantiateResult = .failure(TestError.factoryFailed)
        let callsBefore = avEngineSpy.calls.count

        _ = try? await sut.load(.fake(component: Self.effectComponent), at: 0)

        let calls = Array(avEngineSpy.calls.dropFirst(callsBefore))
        #expect(calls.contains(.detach(first)))
        #expect(!calls.contains(.start))
    }

    @Test
    mutating func load_whileAnotherLoadInstantiates_endsWithBothNodesWired() async throws {
        let first = try await Self.makeAVAudioUnit(Self.effectDescription)
        let second = try await Self.makeAVAudioUnit(Self.effectDescription)
        avAudioUnitFactorySpy.instantiateResult = .success(first)
        createSut()
        let pluginChain = sut!
        let factory = avAudioUnitFactorySpy!
        factory.onInstantiate = {
            factory.onInstantiate = nil
            factory.instantiateResult = .success(second)
            _ = try? await pluginChain.load(.fake(component: Self.effectComponent), at: 1)
            factory.instantiateResult = .success(first)
        }

        let firstLoaded = try await sut.load(.fake(component: Self.effectComponent), at: 0)

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
        avAudioUnitFactorySpy.instantiateResult = .success(first)
        createSut()
        _ = try await sut.load(.fake(component: Self.effectComponent), at: 0)
        avAudioUnitFactorySpy.instantiateResult = .success(middle)
        _ = try await sut.load(.fake(component: Self.effectComponent), at: 1)
        avAudioUnitFactorySpy.instantiateResult = .success(last)
        _ = try await sut.load(.fake(component: Self.effectComponent), at: 2)
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
        let loaded = try await sut.load(.fake(component: Self.effectComponent), at: 0)
        let callsAfterLoad = avEngineSpy.calls

        await sut.unload(at: 0)

        #expect(Array(avEngineSpy.calls.dropFirst(callsAfterLoad.count)) == [.stop, .detach(avAudioUnit), .stop])
        #expect(midiManagerSpy.calls == [.teardownMIDI, .teardownMIDI, .setupMIDI(loaded), .teardownMIDI, .teardownMIDI])
    }

    @Test
    mutating func unload_withoutAudioUnit_stopsAndDisconnectsWithoutDetach() async {
        createSut()

        await sut.unload(at: 0)

        #expect(avEngineSpy.calls == [.stop, .stop])
        #expect(hardwareConnectorSpy.calls == [.disconnect, .disconnect])
        #expect(midiManagerSpy.calls == [.teardownMIDI, .teardownMIDI])
    }

    @Test
    mutating func unload_thenReconnect_leavesEngineUntouched() async throws {
        let avAudioUnit = try await Self.makeAVAudioUnit(Self.effectDescription)
        avAudioUnitFactorySpy.instantiateResult = .success(avAudioUnit)
        createSut()
        _ = try await sut.load(.fake(component: Self.effectComponent), at: 0)
        await sut.unload(at: 0)
        let callsAfterUnload = avEngineSpy.calls

        await sut.reconnect()

        #expect(avEngineSpy.calls == callsAfterUnload)
    }

    // MARK: - reconnect

    @Test
    mutating func reconnect_withoutAudioUnit_leavesEverythingUntouched() async {
        createSut()

        await sut.reconnect()

        #expect(avEngineSpy.calls.isEmpty)
        #expect(hardwareConnectorSpy.calls.isEmpty)
        #expect(midiManagerSpy.calls.isEmpty)
        #expect(avAudioUnitFactorySpy.calls.isEmpty)
    }

    @Test
    mutating func reconnect_withAudioUnit_reconnectsRestartsAndSetsUpMIDI() async throws {
        let avAudioUnit = try await Self.makeAVAudioUnit(Self.effectDescription)
        avAudioUnitFactorySpy.instantiateResult = .success(avAudioUnit)
        createSut()
        let loaded = try await sut.load(.fake(component: Self.effectComponent), at: 0)
        let engineCallsAfterLoad = avEngineSpy.calls.count
        let connectorCallsAfterLoad = hardwareConnectorSpy.calls.count
        let midiCallsAfterLoad = midiManagerSpy.calls.count

        await sut.reconnect()

        #expect(Array(avEngineSpy.calls.dropFirst(engineCallsAfterLoad)) == [.stop, .start])
        #expect(Array(hardwareConnectorSpy.calls.dropFirst(connectorCallsAfterLoad)) == [
            .disconnect,
            .connect(first: avAudioUnit, last: avAudioUnit)
        ])
        #expect(Array(midiManagerSpy.calls.dropFirst(midiCallsAfterLoad)) == [.teardownMIDI, .setupMIDI(loaded)])
        #expect(avAudioUnitFactorySpy.calls.count == 1)
    }

    @Test
    mutating func reconnect_hardwareConnectsAfterLoadingDisconnected_startsChain() async throws {
        let avAudioUnit = try await Self.makeAVAudioUnit(Self.effectDescription)
        avAudioUnitFactorySpy.instantiateResult = .success(avAudioUnit)
        hardwareConnectorSpy.connectResult = false
        createSut()
        let loaded = try await sut.load(.fake(component: Self.effectComponent), at: 0)
        hardwareConnectorSpy.connectResult = true
        let engineCallsAfterLoad = avEngineSpy.calls.count
        let midiCallsAfterLoad = midiManagerSpy.calls.count

        await sut.reconnect()

        #expect(Array(avEngineSpy.calls.dropFirst(engineCallsAfterLoad)) == [.stop, .start])
        #expect(Array(midiManagerSpy.calls.dropFirst(midiCallsAfterLoad)) == [.teardownMIDI, .setupMIDI(loaded)])
    }

    @Test
    mutating func reconnect_hardwareNoLongerConnects_stopsWithoutStartingOrMIDI() async throws {
        let avAudioUnit = try await Self.makeAVAudioUnit(Self.effectDescription)
        avAudioUnitFactorySpy.instantiateResult = .success(avAudioUnit)
        createSut()
        _ = try await sut.load(.fake(component: Self.effectComponent), at: 0)
        hardwareConnectorSpy.connectResult = false
        let engineCallsAfterLoad = avEngineSpy.calls.count
        let midiCallsAfterLoad = midiManagerSpy.calls.count

        await sut.reconnect()

        #expect(Array(avEngineSpy.calls.dropFirst(engineCallsAfterLoad)) == [.stop])
        #expect(Array(midiManagerSpy.calls.dropFirst(midiCallsAfterLoad)) == [.teardownMIDI])
    }
}

// MARK: - Test fixtures

private extension PluginChainTests {
    enum TestError: Error { case factoryFailed }

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

    static var effectComponent: AudioUnitComponent {
        AudioUnitComponent(id: effectDescription.componentID, name: "Dyn", manufacturer: "Apple")
    }

    static var delayComponent: AudioUnitComponent {
        AudioUnitComponent(id: delayDescription.componentID, name: "Delay", manufacturer: "Apple")
    }

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

private extension Result<LoadedAudioUnit, PluginChainLoadError> {
    var component: AudioUnitComponent? {
        try? get().component
    }
}

private extension AudioComponentDescription {
    var componentID: AudioUnitComponent.ID {
        AudioUnitComponent.ID(type: componentType, subType: componentSubType, manufacturer: componentManufacturer)
    }
}
