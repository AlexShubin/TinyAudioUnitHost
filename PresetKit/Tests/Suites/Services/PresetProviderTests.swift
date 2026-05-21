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
    var rawStoreMock: RawPresetStoreMock!
    var libraryMock: AudioUnitComponentsLibraryMock!
    var validatorMock: PresetNameValidatorMock!
    var sut: PresetProviderType!

    init() {
        rawStoreMock = RawPresetStoreMock()
        libraryMock = AudioUnitComponentsLibraryMock()
        validatorMock = PresetNameValidatorMock()
    }

    mutating func createSut() {
        sut = PresetProvider(
            rawStore: rawStoreMock,
            library: libraryMock,
            validator: validatorMock
        )
    }

    // MARK: - presets

    @Test
    mutating func presets_emptyStore_returnsEmpty() {
        createSut()

        #expect(sut.presets == [])
    }

    @Test
    mutating func presets_returnsResolvedPresets() {
        let component = AudioUnitComponent.fake(componentDescription: .fakeEffect)
        rawStoreMock.presets = [
            "MyPreset": rawPreset(matching: component, state: Data([0x01])),
        ]
        libraryMock.components = [component]
        createSut()

        #expect(sut.presets == [Preset(name: "MyPreset", component: component, state: Data([0x01]))])
    }

    @Test
    mutating func presets_componentNotInLibrary_skipsThatPreset() {
        let component = AudioUnitComponent.fake(componentDescription: .fakeEffect)
        rawStoreMock.presets = [
            "Resolved": rawPreset(matching: component, state: Data()),
            "Orphan": RawPreset(componentType: 99, componentSubType: 99, componentManufacturer: 99, state: Data()),
        ]
        libraryMock.components = [component]
        createSut()

        #expect(sut.presets.map(\.name) == ["Resolved"])
    }

    // MARK: - activeName

    @Test
    mutating func activeName_noActive_returnsNil() {
        createSut()

        #expect(sut.activeName == nil)
    }

    @Test
    mutating func activeName_present_returnsName() {
        rawStoreMock.currentActivePreset = RawActivePresetState(name: "MyPreset")
        createSut()

        #expect(sut.activeName == "MyPreset")
    }

    // MARK: - setActive

    @Test
    mutating func setActive_name_savesActivePresetOnRawStore() {
        createSut()

        sut.setActive("MyPreset")

        #expect(rawStoreMock.calls == [.saveActivePreset(RawActivePresetState(name: "MyPreset"))])
    }

    @Test
    mutating func setActive_nil_deletesActivePresetOnRawStore() {
        createSut()

        sut.setActive(nil)

        #expect(rawStoreMock.calls == [.deleteActivePreset])
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
        rawStoreMock.presets = ["MyPreset": rawPreset(matching: component, state: Data([0x01]))]
        libraryMock.components = [component]
        createSut()

        #expect(sut.load(name: "MyPreset") == Preset(name: "MyPreset", component: component, state: Data([0x01])))
    }

    @Test
    mutating func load_componentNotInLibrary_returnsNil() {
        rawStoreMock.presets = [
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
        #expect(rawStoreMock.calls == [.save(expected, name: "MyPreset")])
    }

    // MARK: - saveAs

    @Test
    mutating func saveAs_callsValidatorWithSaveAsMode() {
        createSut()

        _ = try? sut.saveAs(Preset.fake(name: "new"))

        #expect(validatorMock.calls == [.validate(name: "new", mode: .saveAs)])
    }

    @Test
    mutating func saveAs_validatorError_throws() {
        validatorMock.result = .duplicate
        createSut()

        #expect(throws: PresetNameError.duplicate) {
            try sut.saveAs(Preset.fake(name: "existing"))
        }
    }

    @Test
    mutating func saveAs_validatorError_doesNotSave() {
        validatorMock.result = .duplicate
        createSut()

        _ = try? sut.saveAs(Preset.fake(name: "existing"))

        #expect(rawStoreMock.presets.isEmpty)
    }

    @Test
    mutating func saveAs_validatorOk_savesAndReturnsPreset() throws {
        let component = AudioUnitComponent.fake(componentDescription: .fakeEffect)
        let preset = Preset(name: "MyPreset", component: component, state: Data([0xBE, 0xEF]))
        createSut()

        let saved = try sut.saveAs(preset)

        let expectedRaw = rawPreset(matching: component, state: Data([0xBE, 0xEF]))
        #expect(saved == preset)
        #expect(rawStoreMock.calls == [.save(expectedRaw, name: "MyPreset")])
    }

    // MARK: - rename

    @Test
    mutating func rename_callsValidatorWithRenameMode() {
        createSut()

        try? sut.rename(from: "old", to: "new")

        #expect(validatorMock.calls == [.validate(name: "new", mode: .rename(currentName: "old"))])
    }

    @Test
    mutating func rename_validatorError_throws() {
        validatorMock.result = .duplicate
        createSut()

        #expect(throws: PresetNameError.duplicate) {
            try sut.rename(from: "old", to: "new")
        }
    }

    @Test
    mutating func rename_validatorError_doesNotMoveFile() {
        validatorMock.result = .duplicate
        let preset = RawPreset.fake()
        rawStoreMock.presets = ["old": preset]
        createSut()

        try? sut.rename(from: "old", to: "new")

        #expect(rawStoreMock.presets["old"] == preset)
        #expect(rawStoreMock.presets["new"] == nil)
    }

    @Test
    mutating func rename_validatorOk_movesFile() throws {
        let preset = RawPreset.fake(componentType: 5)
        rawStoreMock.presets = ["old": preset]
        createSut()

        try sut.rename(from: "old", to: "new")

        #expect(rawStoreMock.presets["old"] == nil)
        #expect(rawStoreMock.presets["new"] == preset)
    }

    @Test
    mutating func rename_activeMatchesOld_followsToNew() {
        rawStoreMock.presets = ["old": .fake()]
        rawStoreMock.currentActivePreset = RawActivePresetState(name: "old")
        createSut()

        try? sut.rename(from: "old", to: "new")

        #expect(rawStoreMock.currentActivePreset == RawActivePresetState(name: "new"))
    }

    @Test
    mutating func rename_activeDoesNotMatch_leavesActiveUnchanged() {
        rawStoreMock.presets = ["old": .fake()]
        rawStoreMock.currentActivePreset = RawActivePresetState(name: "keeper")
        createSut()

        try? sut.rename(from: "old", to: "new")

        #expect(rawStoreMock.currentActivePreset == RawActivePresetState(name: "keeper"))
    }

    // MARK: - delete

    @Test
    mutating func delete_removesFile() {
        rawStoreMock.presets = ["target": .fake()]
        createSut()

        sut.delete(name: "target")

        #expect(rawStoreMock.presets["target"] == nil)
    }

    @Test
    mutating func delete_activeMatches_clearsActive() {
        rawStoreMock.presets = ["target": .fake()]
        rawStoreMock.currentActivePreset = RawActivePresetState(name: "target")
        createSut()

        sut.delete(name: "target")

        #expect(rawStoreMock.currentActivePreset == nil)
    }

    @Test
    mutating func delete_activeDoesNotMatch_leavesActiveUnchanged() {
        rawStoreMock.presets = ["target": .fake()]
        rawStoreMock.currentActivePreset = RawActivePresetState(name: "keeper")
        createSut()

        sut.delete(name: "target")

        #expect(rawStoreMock.currentActivePreset == RawActivePresetState(name: "keeper"))
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
