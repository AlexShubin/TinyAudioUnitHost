//
//  PresetManagerTests.swift
//  PresetKitTests
//
//  Created by Alex Shubin on 08.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioToolbox
import AudioUnitsKit
import AudioUnitsKitTestSupport
import EngineKit
import EngineKitTestSupport
import Foundation
import StorageKit
import StorageKitTestSupport
import Testing
@testable import PresetKit

@Suite
struct PresetManagerTests {
    var engineMock: EngineMock!
    var rawStoreMock: RawPresetStoreMock!
    var libraryMock: AudioUnitComponentsLibraryMock!
    var sut: PresetManagerType!

    init() {
        engineMock = EngineMock()
        rawStoreMock = RawPresetStoreMock()
        libraryMock = AudioUnitComponentsLibraryMock()
    }

    mutating func createSut() {
        sut = PresetManager(engine: engineMock, rawStore: rawStoreMock, library: libraryMock)
    }

    // MARK: - load

    @Test
    mutating func load_noPresets_returnsNil() async {
        createSut()

        #expect(await sut.load() == nil)
    }

    @Test
    mutating func load_onlyDefault_engineLoadsItAndYieldsFalse() async {
        let component = AudioUnitComponent.fake(componentDescription: .fakeEffect)
        let loaded = LoadedAudioUnit.fake(component: component)
        rawStoreMock = RawPresetStoreMock(presets: ["default": rawPreset(matching: component, state: Data([0x01]))])
        libraryMock = AudioUnitComponentsLibraryMock(components: [component])
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
        let component = AudioUnitComponent.fake(componentDescription: .fakeEffect)
        let loaded = LoadedAudioUnit.fake(component: component)
        rawStoreMock = RawPresetStoreMock(presets: [
            "default": rawPreset(matching: component, state: Data([0x01])),
            "raw_session": rawPreset(matching: component, state: Data([0x02])),
        ])
        libraryMock = AudioUnitComponentsLibraryMock(components: [component])
        engineMock = EngineMock(loadResult: loaded)
        createSut()
        var iterator = sut.isModifiedStream.makeAsyncIterator()

        let result = await sut.load()

        #expect(result == loaded)
        #expect(await engineMock.calls == [.load(component, Data([0x02]))])
        #expect(await iterator.next() == true)
    }

    @Test
    mutating func load_sessionPresentButComponentMissing_fallsBackToDefault() async {
        let component = AudioUnitComponent.fake(componentDescription: .fakeEffect)
        let loaded = LoadedAudioUnit.fake(component: component)
        let sessionRaw = RawPreset.fake(componentType: 99, componentSubType: 99, componentManufacturer: 99)
        rawStoreMock = RawPresetStoreMock(presets: [
            "default": rawPreset(matching: component, state: Data([0x01])),
            "raw_session": sessionRaw,
        ])
        libraryMock = AudioUnitComponentsLibraryMock(components: [component])
        engineMock = EngineMock(loadResult: loaded)
        createSut()
        var iterator = sut.isModifiedStream.makeAsyncIterator()

        let result = await sut.load()

        #expect(result == loaded)
        #expect(await engineMock.calls == [.load(component, Data([0x01]))])
        #expect(await iterator.next() == false)
    }

    @Test
    mutating func load_engineLoadFails_returnsNil() async {
        let component = AudioUnitComponent.fake(componentDescription: .fakeEffect)
        rawStoreMock = RawPresetStoreMock(presets: ["default": rawPreset(matching: component, state: Data([0x01]))])
        libraryMock = AudioUnitComponentsLibraryMock(components: [component])
        createSut()  // engineMock.loadResult is nil

        let result = await sut.load()

        #expect(result == nil)
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
        let component = AudioUnitComponent.fake()
        createSut()  // engineMock.loadResult is nil

        let result = await sut.setCurrent(component)

        #expect(result == nil)
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
        let firstLoaded = LoadedAudioUnit.fake(audioUnit: firstAU)
        let secondLoaded = LoadedAudioUnit.fake(audioUnit: secondAU)
        engineMock = EngineMock(loadResult: firstLoaded)
        createSut()
        var iterator = sut.isModifiedStream.makeAsyncIterator()

        _ = await sut.setCurrent(.fake())
        #expect(await iterator.next() == true)

        await engineMock.setLoadResult(secondLoaded)
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

        #expect(await rawStoreMock.calls == [])
    }

    @Test
    mutating func save_writesDefaultAndDeletesSession() async {
        let component = AudioUnitComponent.fake(componentDescription: .fakeEffect)
        let auMock = AUAudioUnitMock(fullState: Data([0xBE, 0xEF]))
        let loaded = LoadedAudioUnit.fake(component: component, audioUnit: auMock)
        engineMock = EngineMock(loadResult: loaded)
        createSut()
        _ = await sut.setCurrent(component)

        await sut.save()

        let expected = rawPreset(matching: component, state: Data([0xBE, 0xEF]))
        let calls = await rawStoreMock.calls
        #expect(calls == [
            .save(expected, name: "default"),
            .delete(name: "raw_session"),
        ])
    }

    @Test
    mutating func save_yieldsFalse_andPersistSessionDeletes() async {
        let component = AudioUnitComponent.fake(componentDescription: .fakeEffect)
        let auMock = AUAudioUnitMock(fullState: Data([0x42]))
        let loaded = LoadedAudioUnit.fake(component: component, audioUnit: auMock)
        engineMock = EngineMock(loadResult: loaded)
        createSut()
        var iterator = sut.isModifiedStream.makeAsyncIterator()
        _ = await sut.setCurrent(component)
        #expect(await iterator.next() == true)

        await sut.save()
        #expect(await iterator.next() == false)

        await rawStoreMock.setPresets([:])

        await sut.persistSession()

        let calls = await rawStoreMock.calls.suffix(1)
        #expect(calls == [.delete(name: "raw_session")])
    }

    // MARK: - persistSession

    @Test
    mutating func persistSession_notModified_deletesSession() async {
        let component = AudioUnitComponent.fake(componentDescription: .fakeEffect)
        let auMock = AUAudioUnitMock(fullState: Data([0x42]))
        let loaded = LoadedAudioUnit.fake(component: component, audioUnit: auMock)
        rawStoreMock = RawPresetStoreMock(presets: ["default": rawPreset(matching: component, state: Data([0xFF]))])
        libraryMock = AudioUnitComponentsLibraryMock(components: [component])
        engineMock = EngineMock(loadResult: loaded)
        createSut()
        _ = await sut.load()

        await sut.persistSession()

        #expect(await rawStoreMock.calls.last == .delete(name: "raw_session"))
    }

    @Test
    mutating func persistSession_modified_writesSession() async {
        let component = AudioUnitComponent.fake(componentDescription: .fakeEffect)
        let auMock = AUAudioUnitMock(fullState: Data([0xCA, 0xFE]))
        let loaded = LoadedAudioUnit.fake(component: component, audioUnit: auMock)
        engineMock = EngineMock(loadResult: loaded)
        createSut()
        _ = await sut.setCurrent(component)

        await sut.persistSession()

        let expected = rawPreset(matching: component, state: Data([0xCA, 0xFE]))
        #expect(await rawStoreMock.calls == [.save(expected, name: "raw_session")])
    }

    // MARK: - Helpers

    private func rawPreset(matching component: AudioUnitComponent, state: Data) -> RawPreset {
        let desc = component.componentDescription
        return RawPreset(
            componentType: desc.componentType,
            componentSubType: desc.componentSubType,
            componentManufacturer: desc.componentManufacturer,
            state: state
        )
    }
}
