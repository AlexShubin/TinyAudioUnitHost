//
//  RawSettingsStoreTests.swift
//  StorageKitTests
//
//  Created by Alex Shubin on 30.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import StorageKitTestSupport
import Testing
@testable import StorageKit

@Suite
struct RawSettingsStoreTests {
    var fileStorageSpy: FileStorageSpy!
    var sut: RawSettingsStoreType!

    init() {
        fileStorageSpy = FileStorageSpy()
    }

    mutating func createSut() {
        sut = RawSettingsStore(fileStorage: fileStorageSpy)
    }

    @Test
    mutating func current_emptyStorage_returnsEmpty() {
        createSut()

        #expect(sut.current == .empty)
    }

    @Test
    mutating func current_readsStoredSettings() {
        let stored = RawAudioSettings.fake(bufferSize: 256, sampleRate: 48_000)
        fileStorageSpy.storage["audio_settings"] = stored
        createSut()

        #expect(sut.current == stored)
    }

    @Test
    mutating func current_wrongTypeInStorage_returnsEmpty() {
        fileStorageSpy.storage["audio_settings"] = "not a RawAudioSettings"
        createSut()

        #expect(sut.current == .empty)
    }

    @Test
    mutating func save_writesToStorage() throws {
        createSut()

        sut.save(.fake(bufferSize: 512))

        #expect(sut.current.bufferSize == 512)
        let persisted = try #require(fileStorageSpy.storage["audio_settings"] as? RawAudioSettings)
        #expect(persisted.bufferSize == 512)
    }
}
