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
    mutating func load_noRawPreset_returnsNil() async {
        createSut()

        #expect(await sut.load() == nil)
    }

    @Test
    mutating func load_readsRawAtName_default() async {
        createSut()

        _ = await sut.load()

        #expect(await rawStoreMock.calls == [.load(name: "default")])
    }

    @Test
    mutating func load_rawExistsButComponentNotInstalled_returnsNil() async {
        let raw = RawPreset.fake(componentType: 99, componentSubType: 99, componentManufacturer: 99)
        rawStoreMock = RawPresetStoreMock(presets: ["default": raw])
        libraryMock = AudioUnitComponentsLibraryMock(components: [.fake()])
        createSut()

        #expect(await sut.load() == nil)
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

        let preset = await sut.load()

        #expect(preset?.component == component)
        #expect(preset?.state == Data([0xDE, 0xAD]))
    }

    // MARK: - save

    @Test
    mutating func save_fullStateNil_doesNothing() async {
        let auMock = AUAudioUnitMock(fullState: nil)
        let loaded = LoadedAudioUnit.fake(audioUnit: auMock)
        createSut()

        await sut.save(loaded)

        #expect(await rawStoreMock.calls == [])
    }

    @Test
    mutating func save_writesRawAtName_default() async {
        let component = AudioUnitComponent.fake(componentDescription: .fakeEffect)
        let auMock = AUAudioUnitMock(fullState: Data([0xBE, 0xEF]))
        let loaded = LoadedAudioUnit.fake(component: component, audioUnit: auMock)
        createSut()

        await sut.save(loaded)

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
    mutating func save_thenLoad_roundTrips() async {
        let component = AudioUnitComponent.fake(componentDescription: .fakeEffect)
        let auMock = AUAudioUnitMock(fullState: Data([0x01, 0x02]))
        libraryMock = AudioUnitComponentsLibraryMock(components: [component])
        createSut()

        await sut.save(LoadedAudioUnit.fake(component: component, audioUnit: auMock))
        let loaded = await sut.load()

        #expect(loaded == Preset(component: component, state: Data([0x01, 0x02])))
    }
}
