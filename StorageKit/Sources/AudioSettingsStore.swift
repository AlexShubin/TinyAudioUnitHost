//
//  AudioSettingsStore.swift
//  StorageKit
//
//  Created by Alex Shubin on 22.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

public protocol AudioSettingsStoreType: Sendable {
    func current() async -> AudioSettings
    func update(_ transform: @Sendable (inout AudioSettings) -> Void) async
}

final actor AudioSettingsStore: AudioSettingsStoreType {
    private static let key = "audioSettings"
    private let fileStorage: FileStorageType
    private var settings: AudioSettings

    init(fileStorage: FileStorageType) {
        self.fileStorage = fileStorage
        self.settings = fileStorage.read(AudioSettings.self, key: Self.key) ?? .empty
    }

    func current() -> AudioSettings { settings }

    func update(_ transform: @Sendable (inout AudioSettings) -> Void) {
        transform(&settings)
        fileStorage.write(settings, key: Self.key)
    }
}
