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
import PresetKitTestSupport
import StorageKit
import StorageKitTestSupport
import Testing
@testable import PresetKit

@Suite
struct PresetProviderTests {
    var rawStoreSpy: RawPresetStoreSpy!
    var librarySpy: AudioUnitComponentsLibrarySpy!
    var sut: PresetProviderType!

    init() {
        rawStoreSpy = RawPresetStoreSpy()
        librarySpy = AudioUnitComponentsLibrarySpy()
    }

    mutating func createSut() {
        sut = PresetProvider(
            rawStore: rawStoreSpy,
            library: librarySpy
        )
    }

    // MARK: - presets

    @Test
    mutating func presets_emptyStore_returnsEmpty() {
        createSut()

        #expect(sut.presets == [])
    }

    @Test
    mutating func presets_returnsStoredNames() {
        let component = AudioUnitComponent.fake(componentDescription: .fakeEffect)
        rawStoreSpy.presets = [
            "MyPreset": rawPreset(matching: component, state: Data([0x01])),
        ]
        librarySpy.components = [component]
        createSut()

        #expect(sut.presets == ["MyPreset"])
    }

    @Test
    mutating func presets_componentNotInLibrary_stillListsName() {
        let component = AudioUnitComponent.fake(componentDescription: .fakeEffect)
        rawStoreSpy.presets = [
            "Resolved": rawPreset(matching: component, state: Data()),
            "Orphan": RawPreset(componentType: 99, componentSubType: 99, componentManufacturer: 99, state: Data()),
        ]
        librarySpy.components = [component]
        createSut()

        #expect(sut.presets.sorted() == ["Orphan", "Resolved"])
    }

    // MARK: - activeName

    @Test
    mutating func activeName_noActive_returnsNil() {
        createSut()

        #expect(sut.activeName == nil)
    }

    @Test
    mutating func activeName_present_returnsName() {
        rawStoreSpy.currentActivePreset = RawActivePresetState(name: "MyPreset")
        createSut()

        #expect(sut.activeName == "MyPreset")
    }

    // MARK: - setActive

    @Test
    mutating func setActive_name_savesActivePresetOnRawStore() {
        createSut()

        sut.setActive("MyPreset")

        #expect(rawStoreSpy.calls == [.saveActivePreset(RawActivePresetState(name: "MyPreset"))])
    }

    @Test
    mutating func setActive_nil_deletesActivePresetOnRawStore() {
        createSut()

        sut.setActive(nil)

        #expect(rawStoreSpy.calls == [.deleteActivePreset])
    }

    // MARK: - load

    @Test
    mutating func load_missing_returnsNil() {
        createSut()

        #expect(sut.load(name: "missing") == nil)
    }

    @Test
    mutating func load_present_returnsResolvedPreset() {
        let component = AudioUnitComponent.fake(componentDescription: .fakeEffect)
        rawStoreSpy.presets = ["MyPreset": rawPreset(matching: component, state: Data([0x01]))]
        librarySpy.components = [component]
        createSut()

        #expect(sut.load(name: "MyPreset") == Preset(name: "MyPreset", component: component, state: Data([0x01])))
    }

    @Test
    mutating func load_componentNotInLibrary_returnsNil() {
        rawStoreSpy.presets = [
            "Orphan": RawPreset(componentType: 99, componentSubType: 99, componentManufacturer: 99, state: Data()),
        ]
        createSut()

        #expect(sut.load(name: "Orphan") == nil)
    }

    // MARK: - save

    @Test
    mutating func save_writesRawPresetAtName() {
        let component = AudioUnitComponent.fake(componentDescription: .fakeEffect)
        let preset = Preset(name: "MyPreset", component: component, state: Data([0xBE, 0xEF]))
        createSut()

        sut.save(preset)

        let expected = rawPreset(matching: component, state: Data([0xBE, 0xEF]))
        #expect(rawStoreSpy.calls == [.save(expected, name: "MyPreset")])
    }

    // MARK: - saveAs

    // MARK: - rename

    @Test
    mutating func rename_movesFile() {
        let preset = RawPreset.fake(componentType: 5)
        rawStoreSpy.presets = ["old": preset]
        createSut()

        sut.rename(from: "old", to: "new")

        #expect(rawStoreSpy.presets["old"] == nil)
        #expect(rawStoreSpy.presets["new"] == preset)
    }

    @Test
    mutating func rename_activeMatchesOld_followsToNew() {
        rawStoreSpy.presets = ["old": .fake()]
        rawStoreSpy.currentActivePreset = RawActivePresetState(name: "old")
        createSut()

        sut.rename(from: "old", to: "new")

        #expect(rawStoreSpy.currentActivePreset == RawActivePresetState(name: "new"))
    }

    @Test
    mutating func rename_activeDoesNotMatch_leavesActiveUnchanged() {
        rawStoreSpy.presets = ["old": .fake()]
        rawStoreSpy.currentActivePreset = RawActivePresetState(name: "keeper")
        createSut()

        sut.rename(from: "old", to: "new")

        #expect(rawStoreSpy.currentActivePreset == RawActivePresetState(name: "keeper"))
    }

    // MARK: - delete

    @Test
    mutating func delete_removesFile() {
        rawStoreSpy.presets = ["target": .fake()]
        createSut()

        sut.delete(name: "target")

        #expect(rawStoreSpy.presets["target"] == nil)
    }

    @Test
    mutating func delete_activeMatches_clearsActive() {
        rawStoreSpy.presets = ["target": .fake()]
        rawStoreSpy.currentActivePreset = RawActivePresetState(name: "target")
        createSut()

        sut.delete(name: "target")

        #expect(rawStoreSpy.currentActivePreset == nil)
    }

    @Test
    mutating func delete_activeDoesNotMatch_leavesActiveUnchanged() {
        rawStoreSpy.presets = ["target": .fake()]
        rawStoreSpy.currentActivePreset = RawActivePresetState(name: "keeper")
        createSut()

        sut.delete(name: "target")

        #expect(rawStoreSpy.currentActivePreset == RawActivePresetState(name: "keeper"))
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
