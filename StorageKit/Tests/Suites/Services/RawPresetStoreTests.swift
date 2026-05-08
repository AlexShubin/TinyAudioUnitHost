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
    var fileStorageMock: FileStorageMock!
    var sut: RawPresetStoreType!

    init() {
        fileStorageMock = FileStorageMock()
    }

    mutating func createSut() {
        sut = RawPresetStore(fileStorage: fileStorageMock)
    }

    @Test
    mutating func load_missingPreset_returnsNil() async {
        createSut()

        #expect(await sut.load(name: "default") == nil)
    }

    @Test
    mutating func load_existingPreset_returnsIt() async {
        let stored = RawPreset.fake(componentType: 1, state: Data([0xDE, 0xAD]))
        fileStorageMock.storage["presets/default"] = stored
        createSut()

        #expect(await sut.load(name: "default") == stored)
    }

    @Test
    mutating func load_wrongTypeAtPath_returnsNil() async {
        fileStorageMock.storage["presets/default"] = "not a RawPreset"
        createSut()

        #expect(await sut.load(name: "default") == nil)
    }

    @Test
    mutating func save_writesAtPresetsSlashName() async throws {
        createSut()
        let preset = RawPreset.fake(componentType: 42, state: Data([0xBE, 0xEF]))

        await sut.save(preset, name: "default")

        let written = try #require(fileStorageMock.storage["presets/default"] as? RawPreset)
        #expect(written == preset)
    }

    @Test
    mutating func save_thenLoad_roundTrips() async {
        createSut()
        let preset = RawPreset.fake(componentSubType: 7)

        await sut.save(preset, name: "lead")

        #expect(await sut.load(name: "lead") == preset)
    }

    @Test
    mutating func delete_removesAtPresetsSlashName() async {
        let preset = RawPreset.fake()
        fileStorageMock.storage["presets/raw_session"] = preset
        createSut()

        await sut.delete(name: "raw_session")

        #expect(fileStorageMock.storage["presets/raw_session"] == nil)
    }

    @Test
    mutating func delete_missing_isNoop() async {
        createSut()

        await sut.delete(name: "raw_session")

        #expect(fileStorageMock.storage["presets/raw_session"] == nil)
    }
}
