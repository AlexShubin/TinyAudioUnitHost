//
//  ChannelStripTests.swift
//  SessionKitTests
//
//  Created by Alex Shubin on 30.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioToolbox
import AudioUnitsKit
import AVFoundation
import SessionKitTestSupport
import Testing
@testable import SessionKit

@Suite
struct ChannelStripTests {
    var avEngineSpy: AVAudioEngineSpy!
    var avAudioUnitFactorySpy: AVAudioUnitFactorySpy!
    var audioConnectorSpy: AudioConnectorSpy!
    var midiConnectorSpy: MidiConnectorSpy!
    var sut: ChannelStripType!

    init() {
        avEngineSpy = AVAudioEngineSpy()
        avAudioUnitFactorySpy = AVAudioUnitFactorySpy()
        audioConnectorSpy = AudioConnectorSpy()
        midiConnectorSpy = MidiConnectorSpy()
    }

    mutating func createSut() {
        sut = ChannelStrip(
            engine: avEngineSpy,
            avAudioUnitFactory: avAudioUnitFactorySpy,
            audioConnector: audioConnectorSpy,
            midiConnector: midiConnectorSpy
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

        #expect(thrown as? ChannelStripLoadError == .audioUnitInstantiationFailed)
        #expect(avAudioUnitFactorySpy.calls == [.instantiate(Self.effectDescription, .loadOutOfProcess)])
        #expect(audioConnectorSpy.calls == [.disconnect, .disconnect])
        #expect(midiConnectorSpy.calls == [.disconnect, .disconnect])
        #expect(!avEngineSpy.calls.contains(.start))
    }

    @Test
    mutating func load_happyPath_attachesConnectsStartsAndSetsUpMIDI() async throws {
        let avAudioUnit = try await Self.makeAVAudioUnit(Self.effectDescription)
        avAudioUnitFactorySpy.instantiateResult = .success(avAudioUnit)
        createSut()
        await sut.updateHardwareSettings(.fake())

        let result = try await sut.load(.fake(component: Self.effectComponent), at: 0)

        #expect(result.component == Self.effectComponent)
        #expect(avEngineSpy.calls == [.stop, .attach(avAudioUnit), .stop, .start])
        #expect(audioConnectorSpy.calls == [.disconnect, .disconnect, .connect(first: avAudioUnit, last: avAudioUnit, settings: .fake())])
        #expect(midiConnectorSpy.calls == [.disconnect, .disconnect, .connect(result, .fake())])
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

        _ = try await sut.load(.fake(component: Self.effectComponent, state: stateAtMax), at: 0)

        #expect(parameter.value == parameter.maxValue)
    }

    @Test
    mutating func load_replacesPreviousAU_detachesOldAndTearsDownMIDI() async throws {
        let firstAU = try await Self.makeAVAudioUnit(Self.effectDescription)
        let secondAU = try await Self.makeAVAudioUnit(Self.effectDescription)
        avAudioUnitFactorySpy.instantiateResult = .success(firstAU)
        createSut()
        await sut.updateHardwareSettings(.fake())

        let firstResult = try await sut.load(.fake(component: Self.effectComponent), at: 0)
        avAudioUnitFactorySpy.instantiateResult = .success(secondAU)

        let secondResult = try await sut.load(.fake(component: Self.effectComponent), at: 0)

        #expect(avEngineSpy.calls == [
            .stop, .attach(firstAU), .stop, .start,
            .stop, .detach(firstAU), .attach(secondAU), .stop, .start
        ])
        #expect(midiConnectorSpy.calls == [
            .disconnect, .disconnect, .connect(firstResult, .fake()),
            .disconnect, .disconnect, .connect(secondResult, .fake())
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
        audioConnectorSpy.connectResult = false
        createSut()
        await sut.updateHardwareSettings(.fake())

        _ = try await sut.load(.fake(component: Self.effectComponent), at: 0)

        #expect(avEngineSpy.calls == [.stop, .attach(avAudioUnit), .stop])
        #expect(midiConnectorSpy.calls == [.disconnect, .disconnect])
    }

    @Test
    mutating func load_withoutHardwareSettings_keepsNodeWithoutConnectingOrStarting() async throws {
        let avAudioUnit = try await Self.makeAVAudioUnit(Self.effectDescription)
        avAudioUnitFactorySpy.instantiateResult = .success(avAudioUnit)
        createSut()

        _ = try await sut.load(.fake(component: Self.effectComponent), at: 0)

        #expect(audioConnectorSpy.calls == [.disconnect, .disconnect])
        #expect(avEngineSpy.calls == [.stop, .attach(avAudioUnit), .stop])
        #expect(midiConnectorSpy.calls == [.disconnect, .disconnect])
    }

    @Test
    mutating func load_passesHardwareSettingsToConnectors() async throws {
        let avAudioUnit = try await Self.makeAVAudioUnit(Self.effectDescription)
        avAudioUnitFactorySpy.instantiateResult = .success(avAudioUnit)
        createSut()
        await sut.updateHardwareSettings(.fake(audio: .fake(deviceID: 7), midi: .fake(sources: [10])))

        let loaded = try await sut.load(.fake(component: Self.effectComponent), at: 0)

        #expect(audioConnectorSpy.calls.last == .connect(first: avAudioUnit, last: avAudioUnit, settings: .fake(deviceID: 7)))
        #expect(midiConnectorSpy.calls.last == .connect(loaded, .fake(sources: [10])))
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
        await sut.updateHardwareSettings(.fake())

        let results = await sut.load([.fake(component: Self.effectComponent), .fake(component: Self.delayComponent)])

        #expect(results.map(\.?.component) == [Self.effectComponent, Self.delayComponent])
        #expect(avEngineSpy.calls.contains(.attach(first)))
        #expect(avEngineSpy.calls.contains(.attach(second)))
        #expect(avEngineSpy.calls.contains(.connect(first, second, Self.outputFormat(of: first))))
        #expect(audioConnectorSpy.calls.last == .connect(first: first, last: second, settings: .fake()))
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
        await sut.updateHardwareSettings(.fake())

        let results = await sut.load([.fake(component: Self.effectComponent), .fake(component: Self.delayComponent)])

        let firstLoaded = try #require(try results[0]?.get())
        #expect(midiConnectorSpy.calls == [.disconnect, .disconnect, .connect(firstLoaded, .fake())])
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
        await sut.updateHardwareSettings(.fake())

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
        await sut.updateHardwareSettings(.fake())

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
        await sut.updateHardwareSettings(.fake())
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
        await sut.updateHardwareSettings(.fake())
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
        await sut.updateHardwareSettings(.fake())
        _ = try await sut.load(.fake(component: Self.effectComponent), at: 0)
        avAudioUnitFactorySpy.instantiateResult = .success(second)
        let callsBefore = avEngineSpy.calls.count

        _ = try await sut.load(.fake(component: Self.effectComponent), at: 1)

        let calls = Array(avEngineSpy.calls.dropFirst(callsBefore))
        #expect(calls.contains(.connect(first, second, Self.outputFormat(of: first))))
        #expect(audioConnectorSpy.calls.last == .connect(first: first, last: second, settings: .fake()))
        #expect(!calls.contains(.detach(first)))
    }

    @Test
    mutating func load_lowerPositionAfterHigher_ordersChainByPosition() async throws {
        let upper = try await Self.makeAVAudioUnit(Self.effectDescription)
        let lower = try await Self.makeAVAudioUnit(Self.effectDescription)
        avAudioUnitFactorySpy.instantiateResult = .success(upper)
        createSut()
        await sut.updateHardwareSettings(.fake())
        _ = try await sut.load(.fake(component: Self.effectComponent), at: 2)
        avAudioUnitFactorySpy.instantiateResult = .success(lower)
        let callsBefore = avEngineSpy.calls.count

        _ = try await sut.load(.fake(component: Self.effectComponent), at: 1)

        let calls = Array(avEngineSpy.calls.dropFirst(callsBefore))
        #expect(calls.contains(.connect(lower, upper, Self.outputFormat(of: lower))))
        #expect(audioConnectorSpy.calls.last == .connect(first: lower, last: upper, settings: .fake()))
    }

    @Test
    mutating func load_occupiedPosition_detachesOnlyThatNode() async throws {
        let first = try await Self.makeAVAudioUnit(Self.effectDescription)
        let second = try await Self.makeAVAudioUnit(Self.effectDescription)
        let replacement = try await Self.makeAVAudioUnit(Self.effectDescription)
        avAudioUnitFactorySpy.instantiateResult = .success(first)
        createSut()
        await sut.updateHardwareSettings(.fake())
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
        await sut.updateHardwareSettings(.fake())
        let firstLoaded = try await sut.load(.fake(component: Self.effectComponent), at: 0)
        avAudioUnitFactorySpy.instantiateResult = .success(second)

        _ = try await sut.load(.fake(component: Self.effectComponent), at: 1)

        #expect(midiConnectorSpy.calls == [
            .disconnect, .disconnect, .connect(firstLoaded, .fake()),
            .disconnect, .disconnect, .connect(firstLoaded, .fake())
        ])
    }

    @Test
    mutating func load_factoryFailure_restartsRemainingChain() async throws {
        let first = try await Self.makeAVAudioUnit(Self.effectDescription)
        avAudioUnitFactorySpy.instantiateResult = .success(first)
        createSut()
        await sut.updateHardwareSettings(.fake())
        let firstLoaded = try await sut.load(.fake(component: Self.effectComponent), at: 0)
        avAudioUnitFactorySpy.instantiateResult = .failure(TestError.factoryFailed)
        let callsBefore = avEngineSpy.calls.count

        var thrown: ChannelStripLoadError?
        do {
            _ = try await sut.load(.fake(component: Self.effectComponent), at: 1)
        } catch {
            thrown = error
        }

        #expect(thrown == .audioUnitInstantiationFailed)
        #expect(Array(avEngineSpy.calls.dropFirst(callsBefore)).contains(.start))
        #expect(midiConnectorSpy.calls.last == .connect(firstLoaded, .fake()))
    }

    @Test
    mutating func load_factoryFailureAtOccupiedPosition_clearsItAndStaysStopped() async throws {
        let first = try await Self.makeAVAudioUnit(Self.effectDescription)
        avAudioUnitFactorySpy.instantiateResult = .success(first)
        createSut()
        await sut.updateHardwareSettings(.fake())
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
        await sut.updateHardwareSettings(.fake())
        let channelStrip = sut!
        let factory = avAudioUnitFactorySpy!
        factory.onInstantiate = {
            factory.onInstantiate = nil
            factory.instantiateResult = .success(second)
            _ = try? await channelStrip.load(.fake(component: Self.effectComponent), at: 1)
            factory.instantiateResult = .success(first)
        }

        let firstLoaded = try await sut.load(.fake(component: Self.effectComponent), at: 0)

        let lastRebuild = avEngineSpy.calls.suffix(from: try #require(avEngineSpy.calls.lastIndex(of: .stop)))
        #expect(lastRebuild.contains(.connect(first, second, Self.outputFormat(of: first))))
        #expect(avEngineSpy.calls.last == .start)
        #expect(midiConnectorSpy.calls.suffix(2) == [.disconnect, .connect(firstLoaded, .fake())])
    }

    @Test
    mutating func unload_middlePosition_connectsNeighbours() async throws {
        let first = try await Self.makeAVAudioUnit(Self.effectDescription)
        let middle = try await Self.makeAVAudioUnit(Self.effectDescription)
        let last = try await Self.makeAVAudioUnit(Self.effectDescription)
        avAudioUnitFactorySpy.instantiateResult = .success(first)
        createSut()
        await sut.updateHardwareSettings(.fake())
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
        await sut.updateHardwareSettings(.fake())
        let loaded = try await sut.load(.fake(component: Self.effectComponent), at: 0)
        let callsAfterLoad = avEngineSpy.calls

        await sut.unload(at: 0)

        #expect(Array(avEngineSpy.calls.dropFirst(callsAfterLoad.count)) == [.stop, .detach(avAudioUnit), .stop])
        #expect(midiConnectorSpy.calls == [.disconnect, .disconnect, .connect(loaded, .fake()), .disconnect, .disconnect])
    }

    @Test
    mutating func unload_withoutAudioUnit_stopsAndDisconnectsWithoutDetach() async {
        createSut()

        await sut.unload(at: 0)

        #expect(avEngineSpy.calls == [.stop, .stop])
        #expect(audioConnectorSpy.calls == [.disconnect, .disconnect])
        #expect(midiConnectorSpy.calls == [.disconnect, .disconnect])
    }

    @Test
    mutating func unload_thenReconnect_leavesEngineUntouched() async throws {
        let avAudioUnit = try await Self.makeAVAudioUnit(Self.effectDescription)
        avAudioUnitFactorySpy.instantiateResult = .success(avAudioUnit)
        createSut()
        await sut.updateHardwareSettings(.fake())
        _ = try await sut.load(.fake(component: Self.effectComponent), at: 0)
        await sut.unload(at: 0)
        let callsAfterUnload = avEngineSpy.calls

        await sut.reconnect()

        #expect(avEngineSpy.calls == callsAfterUnload)
    }

    // MARK: - updateHardwareSettings

    @Test
    mutating func updateHardwareSettings_firstSettingsAfterLoad_startsChain() async throws {
        let avAudioUnit = try await Self.makeAVAudioUnit(Self.effectDescription)
        avAudioUnitFactorySpy.instantiateResult = .success(avAudioUnit)
        createSut()
        let loaded = try await sut.load(.fake(component: Self.effectComponent), at: 0)
        let engineCallsAfterLoad = avEngineSpy.calls.count
        let midiCallsAfterLoad = midiConnectorSpy.calls.count

        await sut.updateHardwareSettings(.fake())

        #expect(Array(avEngineSpy.calls.dropFirst(engineCallsAfterLoad)) == [.stop, .start])
        #expect(Array(midiConnectorSpy.calls.dropFirst(midiCallsAfterLoad)) == [.disconnect, .connect(loaded, .fake())])
    }

    @Test
    mutating func updateHardwareSettings_audioChanged_reconnectsWithNewSettings() async throws {
        let avAudioUnit = try await Self.makeAVAudioUnit(Self.effectDescription)
        avAudioUnitFactorySpy.instantiateResult = .success(avAudioUnit)
        createSut()
        await sut.updateHardwareSettings(.fake())
        _ = try await sut.load(.fake(component: Self.effectComponent), at: 0)
        let engineCallsBefore = avEngineSpy.calls.count
        let connectorCallsBefore = audioConnectorSpy.calls.count

        await sut.updateHardwareSettings(.fake(audio: .fake(sampleRate: 96_000)))

        #expect(Array(avEngineSpy.calls.dropFirst(engineCallsBefore)) == [.stop, .start])
        #expect(Array(audioConnectorSpy.calls.dropFirst(connectorCallsBefore)) == [
            .disconnect,
            .connect(first: avAudioUnit, last: avAudioUnit, settings: .fake(sampleRate: 96_000))
        ])
    }

    @Test
    mutating func updateHardwareSettings_midiOnlyChanged_reconnectsMidiOnly() async throws {
        let avAudioUnit = try await Self.makeAVAudioUnit(Self.effectDescription)
        avAudioUnitFactorySpy.instantiateResult = .success(avAudioUnit)
        createSut()
        await sut.updateHardwareSettings(.fake())
        _ = try await sut.load(.fake(component: Self.effectComponent), at: 0)
        let engineCallsBefore = avEngineSpy.calls
        let midiCallsBefore = midiConnectorSpy.calls.count

        await sut.updateHardwareSettings(.fake(midi: .fake(sources: [10])))

        #expect(avEngineSpy.calls == engineCallsBefore)
        #expect(Array(midiConnectorSpy.calls.dropFirst(midiCallsBefore)) == [.reconnect(.fake(sources: [10]))])
    }

    @Test
    mutating func updateHardwareSettings_unchanged_leavesEverythingUntouched() async throws {
        let avAudioUnit = try await Self.makeAVAudioUnit(Self.effectDescription)
        avAudioUnitFactorySpy.instantiateResult = .success(avAudioUnit)
        createSut()
        await sut.updateHardwareSettings(.fake())
        _ = try await sut.load(.fake(component: Self.effectComponent), at: 0)
        let engineCallsBefore = avEngineSpy.calls
        let midiCallsBefore = midiConnectorSpy.calls

        await sut.updateHardwareSettings(.fake())

        #expect(avEngineSpy.calls == engineCallsBefore)
        #expect(midiConnectorSpy.calls == midiCallsBefore)
    }

    @Test
    mutating func updateHardwareSettings_nil_stopsWithoutStartingOrMIDI() async throws {
        let avAudioUnit = try await Self.makeAVAudioUnit(Self.effectDescription)
        avAudioUnitFactorySpy.instantiateResult = .success(avAudioUnit)
        createSut()
        await sut.updateHardwareSettings(.fake())
        _ = try await sut.load(.fake(component: Self.effectComponent), at: 0)
        let engineCallsBefore = avEngineSpy.calls.count
        let midiCallsBefore = midiConnectorSpy.calls.count

        await sut.updateHardwareSettings(nil)

        #expect(Array(avEngineSpy.calls.dropFirst(engineCallsBefore)) == [.stop])
        #expect(Array(midiConnectorSpy.calls.dropFirst(midiCallsBefore)) == [.disconnect])
    }

    @Test
    mutating func updateHardwareSettings_withoutPlugins_leavesEngineUntouched() async {
        createSut()

        await sut.updateHardwareSettings(.fake())

        #expect(avEngineSpy.calls.isEmpty)
        #expect(audioConnectorSpy.calls.isEmpty)
        #expect(midiConnectorSpy.calls.isEmpty)
    }

    // MARK: - reconnect

    @Test
    mutating func reconnect_withoutAudioUnit_leavesEverythingUntouched() async {
        createSut()

        await sut.reconnect()

        #expect(avEngineSpy.calls.isEmpty)
        #expect(audioConnectorSpy.calls.isEmpty)
        #expect(midiConnectorSpy.calls.isEmpty)
        #expect(avAudioUnitFactorySpy.calls.isEmpty)
    }

    @Test
    mutating func reconnect_withAudioUnit_reconnectsRestartsAndSetsUpMIDI() async throws {
        let avAudioUnit = try await Self.makeAVAudioUnit(Self.effectDescription)
        avAudioUnitFactorySpy.instantiateResult = .success(avAudioUnit)
        createSut()
        await sut.updateHardwareSettings(.fake())
        let loaded = try await sut.load(.fake(component: Self.effectComponent), at: 0)
        let engineCallsAfterLoad = avEngineSpy.calls.count
        let connectorCallsAfterLoad = audioConnectorSpy.calls.count
        let midiCallsAfterLoad = midiConnectorSpy.calls.count

        await sut.reconnect()

        #expect(Array(avEngineSpy.calls.dropFirst(engineCallsAfterLoad)) == [.stop, .start])
        #expect(Array(audioConnectorSpy.calls.dropFirst(connectorCallsAfterLoad)) == [
            .disconnect,
            .connect(first: avAudioUnit, last: avAudioUnit, settings: .fake())
        ])
        #expect(Array(midiConnectorSpy.calls.dropFirst(midiCallsAfterLoad)) == [.disconnect, .connect(loaded, .fake())])
        #expect(avAudioUnitFactorySpy.calls.count == 1)
    }

    @Test
    mutating func reconnect_hardwareConnectsAfterLoadingDisconnected_startsChain() async throws {
        let avAudioUnit = try await Self.makeAVAudioUnit(Self.effectDescription)
        avAudioUnitFactorySpy.instantiateResult = .success(avAudioUnit)
        audioConnectorSpy.connectResult = false
        createSut()
        await sut.updateHardwareSettings(.fake())
        let loaded = try await sut.load(.fake(component: Self.effectComponent), at: 0)
        audioConnectorSpy.connectResult = true
        let engineCallsAfterLoad = avEngineSpy.calls.count
        let midiCallsAfterLoad = midiConnectorSpy.calls.count

        await sut.reconnect()

        #expect(Array(avEngineSpy.calls.dropFirst(engineCallsAfterLoad)) == [.stop, .start])
        #expect(Array(midiConnectorSpy.calls.dropFirst(midiCallsAfterLoad)) == [.disconnect, .connect(loaded, .fake())])
    }

    @Test
    mutating func reconnect_hardwareNoLongerConnects_stopsWithoutStartingOrMIDI() async throws {
        let avAudioUnit = try await Self.makeAVAudioUnit(Self.effectDescription)
        avAudioUnitFactorySpy.instantiateResult = .success(avAudioUnit)
        createSut()
        await sut.updateHardwareSettings(.fake())
        _ = try await sut.load(.fake(component: Self.effectComponent), at: 0)
        audioConnectorSpy.connectResult = false
        let engineCallsAfterLoad = avEngineSpy.calls.count
        let midiCallsAfterLoad = midiConnectorSpy.calls.count

        await sut.reconnect()

        #expect(Array(avEngineSpy.calls.dropFirst(engineCallsAfterLoad)) == [.stop])
        #expect(Array(midiConnectorSpy.calls.dropFirst(midiCallsAfterLoad)) == [.disconnect])
    }
}

// MARK: - Test fixtures

private extension ChannelStripTests {
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

private extension Result<LoadedAudioUnit, ChannelStripLoadError> {
    var component: AudioUnitComponent? {
        try? get().component
    }
}

private extension AudioComponentDescription {
    var componentID: AudioUnitComponent.ID {
        AudioUnitComponent.ID(type: componentType, subType: componentSubType, manufacturer: componentManufacturer)
    }
}
