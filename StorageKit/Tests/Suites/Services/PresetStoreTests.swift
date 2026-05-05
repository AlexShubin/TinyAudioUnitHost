//
//  PresetStoreTests.swift
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
struct PresetStoreTests {
    var fileStorageMock: FileStorageMock!
    var sut: PresetStoreType!

    init() {
        fileStorageMock = FileStorageMock()
    }

    mutating func createSut() {
        sut = PresetStore(fileStorage: fileStorageMock)
    }

    @Test
    mutating func load_missingPreset_returnsNil() async {
        createSut()

        #expect(await sut.load(name: "default") == nil)
    }

    @Test
    mutating func load_existingPreset_returnsIt() async {
        let stored = Preset.fake(componentType: 1, state: Data([0xDE, 0xAD]))
        fileStorageMock.storage["presets/default"] = stored
        createSut()

        #expect(await sut.load(name: "default") == stored)
    }

    @Test
    mutating func load_wrongTypeAtPath_returnsNil() async {
        fileStorageMock.storage["presets/default"] = "not a Preset"
        createSut()

        #expect(await sut.load(name: "default") == nil)
    }

    @Test
    mutating func save_writesAtPresetsSlashName() async throws {
        createSut()
        let preset = Preset.fake(componentType: 42, state: Data([0xBE, 0xEF]))

        await sut.save(preset, name: "default")

        let written = try #require(fileStorageMock.storage["presets/default"] as? Preset)
        #expect(written == preset)
    }

    @Test
    mutating func save_thenLoad_roundTrips() async {
        createSut()
        let preset = Preset.fake(componentSubType: 7)

        await sut.save(preset, name: "lead")

        #expect(await sut.load(name: "lead") == preset)
    }
}
