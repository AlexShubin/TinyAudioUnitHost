//
//  AudioSettingsStoreTests.swift
//  StorageKitTests
//
//  Created by Alex Shubin on 30.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import StorageKitTestSupport
import Testing
@testable import StorageKit

@Suite
struct AudioSettingsStoreTests {
    var fileStorageMock: FileStorageMock!
    var sut: AudioSettingsStoreType!

    init() {
        fileStorageMock = FileStorageMock()
    }

    mutating func createSut() {
        sut = AudioSettingsStore(fileStorage: fileStorageMock)
    }

    @Test
    mutating func init_emptyStorage_returnsEmpty() async {
        createSut()

        #expect(await sut.current() == .empty)
        #expect(fileStorageMock.calls == [.read("audioSettings")])
    }

    @Test
    mutating func init_readsStoredSettings() async {
        let stored = AudioSettings.fake(bufferSize: 256, sampleRate: 48_000)
        fileStorageMock.storage["audioSettings"] = stored
        createSut()

        #expect(await sut.current() == stored)
        #expect(fileStorageMock.calls == [.read("audioSettings")])
    }

    @Test
    mutating func init_wrongTypeInStorage_returnsEmpty() async {
        fileStorageMock.storage["audioSettings"] = "not an AudioSettings"
        createSut()

        #expect(await sut.current() == .empty)
    }

    @Test
    mutating func update_appliesTransformAndPersists() async throws {
        createSut()

        await sut.update { $0.bufferSize = 512 }

        #expect(await sut.current().bufferSize == 512)
        #expect(fileStorageMock.calls == [.read("audioSettings"), .write("audioSettings")])
        let persisted = try #require(fileStorageMock.storage["audioSettings"] as? AudioSettings)
        #expect(persisted.bufferSize == 512)
    }
}
