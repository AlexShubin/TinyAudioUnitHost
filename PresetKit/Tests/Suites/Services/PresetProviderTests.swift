//
//  PresetProviderTests.swift
//  PresetKitTests
//
//  Created by Alex Shubin on 05.05.26.
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
struct PresetProviderTests {
    var rawStoreMock: RawPresetStoreMock!
    var libraryMock: AudioUnitComponentsLibraryMock!
    var sut: PresetProviderType!

    init() {
        rawStoreMock = RawPresetStoreMock()
        libraryMock = AudioUnitComponentsLibraryMock()
    }

    mutating func createSut() {
        sut = PresetProvider(rawStore: rawStoreMock, library: libraryMock)
    }

    @Test
    mutating func load_noRawPreset_returnsNil() async {
        createSut()

        #expect(await sut.load(slot: .default) == nil)
    }

    @Test
    mutating func load_default_readsRawAtName_default() async {
        createSut()

        _ = await sut.load(slot: .default)

        #expect(await rawStoreMock.calls == [.load(name: "default")])
    }

    @Test
    mutating func load_session_readsRawAtName_rawSession() async {
        createSut()

        _ = await sut.load(slot: .session)

        #expect(await rawStoreMock.calls == [.load(name: "raw_session")])
    }

    @Test
    mutating func load_rawExistsButComponentNotInstalled_returnsNil() async {
        let raw = RawPreset.fake(componentType: 99, componentSubType: 99, componentManufacturer: 99)
        rawStoreMock = RawPresetStoreMock(presets: ["default": raw])
        libraryMock = AudioUnitComponentsLibraryMock(components: [.fake()])
        createSut()

        #expect(await sut.load(slot: .default) == nil)
    }

    @Test
    mutating func load_rawExistsAndComponentInstalled_returnsResolvedPreset() async {
        let component = AudioUnitComponent.fake(componentDescription: .fakeEffect)
        let desc = component.componentDescription
        let raw = RawPreset(
            componentType: desc.componentType,
            componentSubType: desc.componentSubType,
            componentManufacturer: desc.componentManufacturer,
            state: Data([0xDE, 0xAD])
        )
        rawStoreMock = RawPresetStoreMock(presets: ["default": raw])
        libraryMock = AudioUnitComponentsLibraryMock(components: [component])
        createSut()

        let preset = await sut.load(slot: .default)

        #expect(preset?.component == component)
        #expect(preset?.state == Data([0xDE, 0xAD]))
    }

    @Test
    mutating func save_default_writesRawAtName_default() async {
        let component = AudioUnitComponent.fake(componentDescription: .fakeEffect)
        createSut()

        await sut.save(Preset(component: component, state: Data([0xBE, 0xEF])), slot: .default)

        let desc = component.componentDescription
        let expected = RawPreset(
            componentType: desc.componentType,
            componentSubType: desc.componentSubType,
            componentManufacturer: desc.componentManufacturer,
            state: Data([0xBE, 0xEF])
        )
        #expect(await rawStoreMock.calls == [.save(expected, name: "default")])
    }

    @Test
    mutating func save_session_writesRawAtName_rawSession() async {
        let component = AudioUnitComponent.fake(componentDescription: .fakeEffect)
        createSut()

        await sut.save(Preset(component: component, state: Data([0xCA, 0xFE])), slot: .session)

        let desc = component.componentDescription
        let expected = RawPreset(
            componentType: desc.componentType,
            componentSubType: desc.componentSubType,
            componentManufacturer: desc.componentManufacturer,
            state: Data([0xCA, 0xFE])
        )
        #expect(await rawStoreMock.calls == [.save(expected, name: "raw_session")])
    }

    @Test
    mutating func save_thenLoad_roundTrips() async {
        let component = AudioUnitComponent.fake(componentDescription: .fakeEffect)
        libraryMock = AudioUnitComponentsLibraryMock(components: [component])
        createSut()
        let preset = Preset(component: component, state: Data([0x01, 0x02]))

        await sut.save(preset, slot: .default)
        let loaded = await sut.load(slot: .default)

        #expect(loaded == preset)
    }
}
