//
//  AudioSettingsStoreTests.swift
//  StorageKitTests
//
//  Created by Alex Shubin on 30.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import Foundation
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
    mutating func init_readsStoredSettings() async throws {
        let stored = AudioSettings.fake(bufferSize: 256, sampleRate: 48_000)
        fileStorageMock.storage["audioSettings"] = try JSONEncoder().encode(stored)
        createSut()

        #expect(await sut.current() == stored)
        #expect(fileStorageMock.calls == [.read("audioSettings")])
    }

    @Test
    mutating func init_corruptedStorage_returnsEmpty() async {
        fileStorageMock.storage["audioSettings"] = Data([0xFF, 0xFE, 0xFD])
        createSut()

        #expect(await sut.current() == .empty)
    }

    @Test
    mutating func update_appliesTransformAndPersists() async throws {
        createSut()

        await sut.update { $0.bufferSize = 512 }

        #expect(await sut.current().bufferSize == 512)
        #expect(fileStorageMock.calls == [.read("audioSettings"), .write("audioSettings")])
        let persisted = try #require(fileStorageMock.storage["audioSettings"])
        let decoded = try JSONDecoder().decode(AudioSettings.self, from: persisted)
        #expect(decoded.bufferSize == 512)
    }
}
