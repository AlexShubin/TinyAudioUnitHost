//
//  SessionManagerTests.swift
//  TinyAudioUnitHostTests
//
//  Created by Alex Shubin on 09.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioUnitsKit
import AudioUnitsKitTestSupport
import EngineKit
import EngineKitTestSupport
import Foundation
import PresetKit
import PresetKitTestSupport
import Testing
@testable import TinyAudioUnitHost

@Suite
struct SessionManagerTests {
    var presetProviderMock: PresetProviderMock!
    var engineMock: EngineMock!
    var sut: SessionManagerType!

    init() {
        presetProviderMock = PresetProviderMock()
        engineMock = EngineMock()
    }

    mutating func createSut() {
        sut = SessionManager(presetProvider: presetProviderMock, engine: engineMock)
    }

    // MARK: - load

    @Test
    mutating func load_noPresets_returnsNil() async {
        createSut()

        #expect(await sut.load() == nil)
    }

    @Test
    mutating func load_onlyDefault_engineLoadsItAndYieldsFalse() async {
        let component = AudioUnitComponent.fake()
        let preset = Preset(component: component, state: Data([0x01]))
        let loaded = LoadedAudioUnit.fake(component: component)
        presetProviderMock = PresetProviderMock(defaultPreset: preset)
        engineMock = EngineMock(loadResult: loaded)
        createSut()
        var iterator = sut.isModifiedStream.makeAsyncIterator()

        let result = await sut.load()

        #expect(result == loaded)
        #expect(await engineMock.calls == [.load(component, Data([0x01]))])
        #expect(await iterator.next() == false)
    }

    @Test
    mutating func load_sessionPresent_engineLoadsItAndYieldsTrue() async {
        let component = AudioUnitComponent.fake()
        let session = Preset(component: component, state: Data([0x02]))
        let saved = Preset(component: component, state: Data([0x01]))
        let loaded = LoadedAudioUnit.fake(component: component)
        presetProviderMock = PresetProviderMock(defaultPreset: saved, sessionPreset: session)
        engineMock = EngineMock(loadResult: loaded)
        createSut()
        var iterator = sut.isModifiedStream.makeAsyncIterator()

        let result = await sut.load()

        #expect(result == loaded)
        #expect(await engineMock.calls == [.load(component, Data([0x02]))])
        #expect(await iterator.next() == true)
    }

    @Test
    mutating func load_engineLoadFails_returnsNil() async {
        let component = AudioUnitComponent.fake()
        presetProviderMock = PresetProviderMock(defaultPreset: Preset(component: component, state: Data()))
        createSut()  // engineMock.loadResult is nil

        #expect(await sut.load() == nil)
    }

    // MARK: - setCurrent

    @Test
    mutating func setCurrent_engineLoads_yieldsTrue_returnsLoaded() async {
        let component = AudioUnitComponent.fake()
        let loaded = LoadedAudioUnit.fake(component: component)
        engineMock = EngineMock(loadResult: loaded)
        createSut()
        var iterator = sut.isModifiedStream.makeAsyncIterator()

        let result = await sut.setCurrent(component)

        #expect(result == loaded)
        #expect(await engineMock.calls == [.load(component, nil)])
        #expect(await iterator.next() == true)
    }

    @Test
    mutating func setCurrent_engineLoadFails_returnsNil() async {
        createSut()  // engineMock.loadResult is nil

        #expect(await sut.setCurrent(.fake()) == nil)
    }

    @Test
    mutating func setCurrent_paramChange_yieldsTrue() async {
        let auMock = AUAudioUnitMock()
        let loaded = LoadedAudioUnit.fake(audioUnit: auMock)
        engineMock = EngineMock(loadResult: loaded)
        createSut()
        var iterator = sut.isModifiedStream.makeAsyncIterator()
        _ = await sut.setCurrent(.fake())
        #expect(await iterator.next() == true)

        auMock.triggerOnChange()

        #expect(await iterator.next() == true)
    }

    @Test
    mutating func setCurrent_replacesObserver_oldAUStopsTriggering() async {
        let firstAU = AUAudioUnitMock()
        let secondAU = AUAudioUnitMock()
        engineMock = EngineMock(loadResult: LoadedAudioUnit.fake(audioUnit: firstAU))
        createSut()
        var iterator = sut.isModifiedStream.makeAsyncIterator()

        _ = await sut.setCurrent(.fake())
        #expect(await iterator.next() == true)

        await engineMock.setLoadResult(LoadedAudioUnit.fake(audioUnit: secondAU))
        _ = await sut.setCurrent(.fake())
        #expect(await iterator.next() == true)

        secondAU.triggerOnChange()
        #expect(await iterator.next() == true)
    }

    // MARK: - save

    @Test
    mutating func save_noCurrent_doesNothing() async {
        createSut()

        await sut.save()

        #expect(await presetProviderMock.calls == [])
    }

    @Test
    mutating func save_writesDefaultThroughProvider_yieldsFalse() async {
        let component = AudioUnitComponent.fake()
        let auMock = AUAudioUnitMock(fullState: Data([0xBE, 0xEF]))
        let loaded = LoadedAudioUnit.fake(component: component, audioUnit: auMock)
        engineMock = EngineMock(loadResult: loaded)
        createSut()
        var iterator = sut.isModifiedStream.makeAsyncIterator()
        _ = await sut.setCurrent(component)
        #expect(await iterator.next() == true)

        await sut.save()

        #expect(await iterator.next() == false)
        let expected = Preset(component: component, state: Data([0xBE, 0xEF]))
        #expect(await presetProviderMock.calls == [.saveDefault(expected)])
    }

    // MARK: - persistSession

    @Test
    mutating func persistSession_notModified_deletesSessionViaProvider() async {
        let component = AudioUnitComponent.fake()
        let auMock = AUAudioUnitMock(fullState: Data([0x42]))
        let loaded = LoadedAudioUnit.fake(component: component, audioUnit: auMock)
        let savedPreset = Preset(component: component, state: Data([0xFF]))
        presetProviderMock = PresetProviderMock(defaultPreset: savedPreset)
        engineMock = EngineMock(loadResult: loaded)
        createSut()
        _ = await sut.load()

        await sut.persistSession()

        #expect(await presetProviderMock.calls.last == .deleteSession)
    }

    @Test
    mutating func persistSession_modified_writesSessionViaProvider() async {
        let component = AudioUnitComponent.fake()
        let auMock = AUAudioUnitMock(fullState: Data([0xCA, 0xFE]))
        let loaded = LoadedAudioUnit.fake(component: component, audioUnit: auMock)
        engineMock = EngineMock(loadResult: loaded)
        createSut()
        _ = await sut.setCurrent(component)

        await sut.persistSession()

        let expected = Preset(component: component, state: Data([0xCA, 0xFE]))
        #expect(await presetProviderMock.calls.last == .saveSession(expected))
    }
}
