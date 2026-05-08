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

    // MARK: - loadActive

    @Test
    mutating func loadActive_noRawPresets_returnsNil() async {
        createSut()

        #expect(await sut.loadActive() == nil)
    }

    @Test
    mutating func loadActive_onlyDefault_returnsItUnmodified() async {
        let component = AudioUnitComponent.fake(componentDescription: .fakeEffect)
        let raw = rawPreset(matching: component, state: Data([0xDE, 0xAD]))
        rawStoreMock = RawPresetStoreMock(presets: ["default": raw])
        libraryMock = AudioUnitComponentsLibraryMock(components: [component])
        createSut()

        let active = await sut.loadActive()

        #expect(active?.preset.component == component)
        #expect(active?.preset.state == Data([0xDE, 0xAD]))
        #expect(active?.isModified == false)
    }

    @Test
    mutating func loadActive_sessionMatchesDefault_returnsSessionUnmodified() async {
        let component = AudioUnitComponent.fake(componentDescription: .fakeEffect)
        let raw = rawPreset(matching: component, state: Data([0x01, 0x02]))
        rawStoreMock = RawPresetStoreMock(presets: ["default": raw, "raw_session": raw])
        libraryMock = AudioUnitComponentsLibraryMock(components: [component])
        createSut()

        let active = await sut.loadActive()

        #expect(active?.preset.state == Data([0x01, 0x02]))
        #expect(active?.isModified == false)
    }

    @Test
    mutating func loadActive_sessionDiffersFromDefault_returnsSessionModified() async {
        let component = AudioUnitComponent.fake(componentDescription: .fakeEffect)
        let savedRaw = rawPreset(matching: component, state: Data([0x01]))
        let sessionRaw = rawPreset(matching: component, state: Data([0x02]))
        rawStoreMock = RawPresetStoreMock(presets: ["default": savedRaw, "raw_session": sessionRaw])
        libraryMock = AudioUnitComponentsLibraryMock(components: [component])
        createSut()

        let active = await sut.loadActive()

        #expect(active?.preset.state == Data([0x02]))
        #expect(active?.isModified == true)
    }

    @Test
    mutating func loadActive_onlySession_returnsItModified() async {
        let component = AudioUnitComponent.fake(componentDescription: .fakeEffect)
        let raw = rawPreset(matching: component, state: Data([0xCA, 0xFE]))
        rawStoreMock = RawPresetStoreMock(presets: ["raw_session": raw])
        libraryMock = AudioUnitComponentsLibraryMock(components: [component])
        createSut()

        let active = await sut.loadActive()

        #expect(active?.preset.state == Data([0xCA, 0xFE]))
        #expect(active?.isModified == true)
    }

    @Test
    mutating func loadActive_componentNotInstalled_returnsNil() async {
        let raw = RawPreset.fake(componentType: 99, componentSubType: 99, componentManufacturer: 99)
        rawStoreMock = RawPresetStoreMock(presets: ["default": raw])
        libraryMock = AudioUnitComponentsLibraryMock(components: [.fake()])
        createSut()

        #expect(await sut.loadActive() == nil)
    }

    // MARK: - save

    @Test
    mutating func save_noCurrent_doesNothing() async {
        createSut()

        await sut.save()

        #expect(await rawStoreMock.calls == [])
    }

    @Test
    mutating func save_currentSet_writesToBothDefaultAndSession() async {
        let component = AudioUnitComponent.fake(componentDescription: .fakeEffect)
        let auMock = AUAudioUnitMock(fullState: Data([0xBE, 0xEF]))
        let loaded = LoadedAudioUnit.fake(component: component, audioUnit: auMock)
        createSut()
        await sut.setCurrent(loaded)

        await sut.save()

        let expected = rawPreset(matching: component, state: Data([0xBE, 0xEF]))
        let calls = await rawStoreMock.calls
        #expect(calls == [
            .save(expected, name: "default"),
            .save(expected, name: "raw_session"),
        ])
    }

    // MARK: - persistSession

    @Test
    mutating func persistSession_noCurrent_doesNothing() async {
        createSut()

        await sut.persistSession()

        #expect(await rawStoreMock.calls == [])
    }

    @Test
    mutating func persistSession_currentSet_writesOnlyToSession() async {
        let component = AudioUnitComponent.fake(componentDescription: .fakeEffect)
        let auMock = AUAudioUnitMock(fullState: Data([0xCA, 0xFE]))
        let loaded = LoadedAudioUnit.fake(component: component, audioUnit: auMock)
        createSut()
        await sut.setCurrent(loaded)

        await sut.persistSession()

        let expected = rawPreset(matching: component, state: Data([0xCA, 0xFE]))
        #expect(await rawStoreMock.calls == [.save(expected, name: "raw_session")])
    }

    @Test
    mutating func setCurrent_replacesPrevious() async {
        let component = AudioUnitComponent.fake(componentDescription: .fakeEffect)
        let firstAU = AUAudioUnitMock(fullState: Data([0x11]))
        let secondAU = AUAudioUnitMock(fullState: Data([0x22]))
        createSut()
        await sut.setCurrent(LoadedAudioUnit.fake(component: component, audioUnit: firstAU))

        await sut.setCurrent(LoadedAudioUnit.fake(component: component, audioUnit: secondAU))
        await sut.persistSession()

        let expected = rawPreset(matching: component, state: Data([0x22]))
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
