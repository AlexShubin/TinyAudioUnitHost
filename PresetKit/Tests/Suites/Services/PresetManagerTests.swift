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
import Foundation
import StorageKit
import StorageKitTestSupport
import Testing
@testable import PresetKit

@Suite
struct PresetManagerTests {
    var rawStoreMock: RawPresetStoreMock!
    var libraryMock: AudioUnitComponentsLibraryMock!
    var sut: PresetManagerType!

    init() {
        rawStoreMock = RawPresetStoreMock()
        libraryMock = AudioUnitComponentsLibraryMock()
    }

    mutating func createSut() {
        sut = PresetManager(rawStore: rawStoreMock, library: libraryMock)
    }

    // MARK: - load

    @Test
    mutating func load_noPresets_returnsNil() async {
        createSut()

        #expect(await sut.load() == nil)
    }

    @Test
    mutating func load_onlyDefault_returnsItUnmodified() async {
        let component = AudioUnitComponent.fake(componentDescription: .fakeEffect)
        rawStoreMock = RawPresetStoreMock(presets: ["default": rawPreset(matching: component, state: Data([0x01]))])
        libraryMock = AudioUnitComponentsLibraryMock(components: [component])
        createSut()

        let active = await sut.load()

        #expect(active?.preset.component == component)
        #expect(active?.preset.state == Data([0x01]))
        #expect(active?.isModified == false)
    }

    @Test
    mutating func load_sessionPresent_returnsItModified() async {
        let component = AudioUnitComponent.fake(componentDescription: .fakeEffect)
        rawStoreMock = RawPresetStoreMock(presets: [
            "default": rawPreset(matching: component, state: Data([0x01])),
            "raw_session": rawPreset(matching: component, state: Data([0x02])),
        ])
        libraryMock = AudioUnitComponentsLibraryMock(components: [component])
        createSut()

        let active = await sut.load()

        #expect(active?.preset.state == Data([0x02]))
        #expect(active?.isModified == true)
    }

    @Test
    mutating func load_sessionPresentButComponentMissing_fallsBackToDefault() async {
        let component = AudioUnitComponent.fake(componentDescription: .fakeEffect)
        // Session references a component that isn't installed.
        let sessionRaw = RawPreset.fake(componentType: 99, componentSubType: 99, componentManufacturer: 99)
        rawStoreMock = RawPresetStoreMock(presets: [
            "default": rawPreset(matching: component, state: Data([0x01])),
            "raw_session": sessionRaw,
        ])
        libraryMock = AudioUnitComponentsLibraryMock(components: [component])
        createSut()

        let active = await sut.load()

        #expect(active?.preset.state == Data([0x01]))
        #expect(active?.isModified == false)
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
        createSut()
        await sut.setCurrent(LoadedAudioUnit.fake(component: component, audioUnit: auMock))

        await sut.save()

        let expected = rawPreset(matching: component, state: Data([0xBE, 0xEF]))
        let calls = await rawStoreMock.calls
        #expect(calls == [
            .save(expected, name: "default"),
            .delete(name: "raw_session"),
        ])
    }

    @Test
    mutating func save_clearsIsModified_soPersistSessionDeletes() async {
        let component = AudioUnitComponent.fake(componentDescription: .fakeEffect)
        let auMock = AUAudioUnitMock(fullState: Data([0x42]))
        createSut()
        await sut.setCurrent(LoadedAudioUnit.fake(component: component, audioUnit: auMock))
        await sut.setModified()
        await sut.save()
        await rawStoreMock.setPresets([:])  // ignore prior calls' state

        await sut.persistSession()

        let calls = await rawStoreMock.calls.suffix(1)
        #expect(calls == [.delete(name: "raw_session")])
    }

    // MARK: - persistSession

    @Test
    mutating func persistSession_notModified_deletesSession() async {
        let component = AudioUnitComponent.fake(componentDescription: .fakeEffect)
        let auMock = AUAudioUnitMock(fullState: Data([0x42]))
        createSut()
        await sut.setCurrent(LoadedAudioUnit.fake(component: component, audioUnit: auMock))

        await sut.persistSession()

        #expect(await rawStoreMock.calls == [.delete(name: "raw_session")])
    }

    @Test
    mutating func persistSession_modified_writesSession() async {
        let component = AudioUnitComponent.fake(componentDescription: .fakeEffect)
        let auMock = AUAudioUnitMock(fullState: Data([0xCA, 0xFE]))
        createSut()
        await sut.setCurrent(LoadedAudioUnit.fake(component: component, audioUnit: auMock))
        await sut.setModified()

        await sut.persistSession()

        let expected = rawPreset(matching: component, state: Data([0xCA, 0xFE]))
        #expect(await rawStoreMock.calls == [.save(expected, name: "raw_session")])
    }

    @Test
    mutating func persistSession_noCurrent_andModified_stillDeletesSession() async {
        createSut()
        await sut.setModified()

        await sut.persistSession()

        // No current loaded — nothing to write. We treat that as "delete session"
        // (consistent with the not-modified case).
        #expect(await rawStoreMock.calls == [.delete(name: "raw_session")])
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
