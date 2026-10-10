//
//  RawPresetStoreTests.swift
//  StorageKitTests
//
//  Created by Alex Shubin on 05.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import Foundation
import StorageKitTestSupport
import Testing
@testable import StorageKit

@Suite
struct RawPresetStoreTests {
    var fileStorageSpy: FileStorageSpy!
    var sut: RawPresetStoreType!

    init() {
        fileStorageSpy = FileStorageSpy()
    }

    mutating func createSut() {
        sut = RawPresetStore(fileStorage: fileStorageSpy)
    }

    // MARK: - names

    @Test
    mutating func names_emptyStorage_returnsEmpty() {
        createSut()

        #expect(sut.names == [])
    }

    @Test
    mutating func names_multiplePresets_returnsSortedCaseInsensitively() {
        fileStorageSpy.storage["presets/zoo"] = RawPreset.fake()
        fileStorageSpy.storage["presets/alpha"] = RawPreset.fake()
        fileStorageSpy.storage["presets/Bravo"] = RawPreset.fake()
        createSut()

        #expect(sut.names == ["alpha", "Bravo", "zoo"])
    }

    @Test
    mutating func names_ignoresActivePresetFile() {
        fileStorageSpy.storage["presets/alpha"] = RawPreset.fake()
        fileStorageSpy.storage["active_preset"] = RawActivePresetState.fake(name: "alpha")
        createSut()

        #expect(sut.names == ["alpha"])
    }

    // MARK: - load

    @Test
    mutating func load_missingPreset_returnsNil() {
        createSut()

        #expect(sut.load(name: "default") == nil)
    }

    @Test
    mutating func load_existingPreset_returnsIt() {
        let stored = RawPreset.fake(componentType: 1, state: Data([0xDE, 0xAD]))
        fileStorageSpy.storage["presets/default"] = stored
        createSut()

        #expect(sut.load(name: "default") == stored)
    }

    @Test
    mutating func load_wrongTypeAtPath_returnsNil() {
        fileStorageSpy.storage["presets/default"] = "not a RawPreset"
        createSut()

        #expect(sut.load(name: "default") == nil)
    }

    // MARK: - save

    @Test
    mutating func save_writesAtPresetsSlashName() throws {
        createSut()
        let preset = RawPreset.fake(componentType: 42, state: Data([0xBE, 0xEF]))

        sut.save(preset, name: "default")

        let written = try #require(fileStorageSpy.storage["presets/default"] as? RawPreset)
        #expect(written == preset)
    }

    @Test
    mutating func save_thenLoad_roundTrips() {
        createSut()
        let preset = RawPreset.fake(componentSubType: 7)

        sut.save(preset, name: "lead")

        #expect(sut.load(name: "lead") == preset)
    }

    // MARK: - rename

    @Test
    mutating func rename_movesFile() {
        let preset = RawPreset.fake(componentType: 5)
        fileStorageSpy.storage["presets/old"] = preset
        createSut()

        sut.rename(from: "old", to: "new")

        #expect(fileStorageSpy.storage["presets/old"] == nil)
        #expect(fileStorageSpy.storage["presets/new"] as? RawPreset == preset)
    }

    @Test
    mutating func rename_doesNotTouchActivePreset() {
        fileStorageSpy.storage["presets/old"] = RawPreset.fake()
        fileStorageSpy.storage["active_preset"] = RawActivePresetState.fake(name: "old")
        createSut()

        sut.rename(from: "old", to: "new")

        // The store is a thin wrapper — it does not adjust active state on rename.
        // PresetProvider is responsible for that policy.
        #expect(sut.activePreset == RawActivePresetState(name: "old"))
    }

    // MARK: - delete

    @Test
    mutating func delete_removesAtPresetsSlashName() {
        let preset = RawPreset.fake()
        fileStorageSpy.storage["presets/raw_session"] = preset
        createSut()

        sut.delete(name: "raw_session")

        #expect(fileStorageSpy.storage["presets/raw_session"] == nil)
    }

    @Test
    mutating func delete_missing_isNoop() {
        createSut()

        sut.delete(name: "raw_session")

        #expect(fileStorageSpy.storage["presets/raw_session"] == nil)
    }

    @Test
    mutating func delete_doesNotTouchActivePreset() {
        fileStorageSpy.storage["presets/foo"] = RawPreset.fake()
        fileStorageSpy.storage["active_preset"] = RawActivePresetState.fake(name: "foo")
        createSut()

        sut.delete(name: "foo")

        // The store does not clear active state when its file is deleted —
        // that policy lives in PresetProvider.
        #expect(sut.activePreset == RawActivePresetState(name: "foo"))
    }

    // MARK: - activePreset

    @Test
    mutating func activePreset_noStateFile_returnsNil() {
        createSut()

        #expect(sut.activePreset == nil)
    }

    @Test
    mutating func activePreset_filePresent_returnsValue() {
        fileStorageSpy.storage["active_preset"] = RawActivePresetState.fake(name: "saved")
        createSut()

        #expect(sut.activePreset == RawActivePresetState(name: "saved"))
    }

    // MARK: - saveActivePreset

    @Test
    mutating func saveActivePreset_writesToStateFile() {
        createSut()

        sut.saveActivePreset(RawActivePresetState(name: "chosen"))

        let written = fileStorageSpy.storage["active_preset"] as? RawActivePresetState
        #expect(written?.name == "chosen")
    }

    @Test
    mutating func saveActivePreset_thenActivePreset_roundTrips() {
        createSut()

        sut.saveActivePreset(RawActivePresetState(name: "foo"))

        #expect(sut.activePreset == RawActivePresetState(name: "foo"))
    }

    // MARK: - deleteActivePreset

    @Test
    mutating func deleteActivePreset_removesStateFile() {
        fileStorageSpy.storage["active_preset"] = RawActivePresetState.fake(name: "before")
        createSut()

        sut.deleteActivePreset()

        #expect(fileStorageSpy.storage["active_preset"] == nil)
    }

    @Test
    mutating func deleteActivePreset_missing_isNoop() {
        createSut()

        sut.deleteActivePreset()

        #expect(fileStorageSpy.storage["active_preset"] == nil)
    }
}
