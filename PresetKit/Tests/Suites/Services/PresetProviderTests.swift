//
//  PresetProviderTests.swift
//  PresetKitTests
//
//  Created by Alex Shubin on 09.05.26.
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

    // MARK: - loadDefault

    @Test
    mutating func loadDefault_absent_returnsNil() async {
        createSut()

        #expect(await sut.loadDefault() == nil)
    }

    @Test
    mutating func loadDefault_present_returnsResolvedPreset() async {
        let component = AudioUnitComponent.fake(componentDescription: .fakeEffect)
        rawStoreMock = RawPresetStoreMock(presets: ["default": rawPreset(matching: component, state: Data([0x01]))])
        libraryMock = AudioUnitComponentsLibraryMock(components: [component])
        createSut()

        let preset = await sut.loadDefault()

        #expect(preset?.component == component)
        #expect(preset?.state == Data([0x01]))
    }

    @Test
    mutating func loadDefault_componentMissing_returnsNil() async {
        rawStoreMock = RawPresetStoreMock(presets: [
            "default": RawPreset.fake(componentType: 99, componentSubType: 99, componentManufacturer: 99),
        ])
        createSut()

        #expect(await sut.loadDefault() == nil)
    }

    // MARK: - loadSession

    @Test
    mutating func loadSession_present_returnsResolvedPreset() async {
        let component = AudioUnitComponent.fake(componentDescription: .fakeEffect)
        rawStoreMock = RawPresetStoreMock(presets: ["raw_session": rawPreset(matching: component, state: Data([0x02]))])
        libraryMock = AudioUnitComponentsLibraryMock(components: [component])
        createSut()

        let preset = await sut.loadSession()

        #expect(preset?.component == component)
        #expect(preset?.state == Data([0x02]))
    }

    @Test
    mutating func loadSession_absent_returnsNil() async {
        createSut()

        #expect(await sut.loadSession() == nil)
    }

    // MARK: - saveDefault

    @Test
    mutating func saveDefault_writesDefault_andDeletesSession() async {
        let component = AudioUnitComponent.fake(componentDescription: .fakeEffect)
        let preset = Preset(component: component, state: Data([0xBE, 0xEF]))
        createSut()

        await sut.saveDefault(preset)

        let expected = rawPreset(matching: component, state: Data([0xBE, 0xEF]))
        #expect(await rawStoreMock.calls == [
            .save(expected, name: "default"),
            .delete(name: "raw_session"),
        ])
    }

    // MARK: - saveSession

    @Test
    mutating func saveSession_writesSession() async {
        let component = AudioUnitComponent.fake(componentDescription: .fakeEffect)
        let preset = Preset(component: component, state: Data([0xCA, 0xFE]))
        createSut()

        await sut.saveSession(preset)

        let expected = rawPreset(matching: component, state: Data([0xCA, 0xFE]))
        #expect(await rawStoreMock.calls == [.save(expected, name: "raw_session")])
    }

    // MARK: - deleteSession

    @Test
    mutating func deleteSession_callsRawStoreDelete() async {
        createSut()

        await sut.deleteSession()

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
