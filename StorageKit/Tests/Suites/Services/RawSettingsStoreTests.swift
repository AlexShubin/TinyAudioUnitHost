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
    var fileStorageMock: FileStorageMock!
    var sut: RawSettingsStoreType!

    init() {
        fileStorageMock = FileStorageMock()
    }

    mutating func createSut() {
        sut = RawSettingsStore(fileStorage: fileStorageMock)
    }

    @Test
    mutating func current_emptyStorage_returnsEmpty() {
        createSut()

        #expect(sut.current == .empty)
    }

    @Test
    mutating func current_readsStoredSettings() {
        let stored = RawAudioSettings.fake(bufferSize: 256, sampleRate: 48_000)
        fileStorageMock.storage["audio_settings"] = stored
        createSut()

        #expect(sut.current == stored)
    }

    @Test
    mutating func current_wrongTypeInStorage_returnsEmpty() {
        fileStorageMock.storage["audio_settings"] = "not a RawAudioSettings"
        createSut()

        #expect(sut.current == .empty)
    }

    @Test
    mutating func update_appliesTransformAndPersists() throws {
        createSut()

        sut.update { $0.bufferSize = 512 }

        #expect(sut.current.bufferSize == 512)
        let persisted = try #require(fileStorageMock.storage["audio_settings"] as? RawAudioSettings)
        #expect(persisted.bufferSize == 512)
    }
}
