//
//  RawSettingsStore.swift
//  StorageKit
//
//  Created by Alex Shubin on 22.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

public protocol RawSettingsStoreType: Sendable {
    func current() async -> RawAudioSettings
    func update(_ transform: @Sendable (inout RawAudioSettings) -> Void) async
}

final actor RawSettingsStore: RawSettingsStoreType {
    private static let path = "audio_settings"
    private let fileStorage: FileStorageType
    private var settings: RawAudioSettings

    init(fileStorage: FileStorageType) {
        self.fileStorage = fileStorage
        self.settings = fileStorage.read(RawAudioSettings.self, at: Self.path) ?? .empty
    }

    func current() -> RawAudioSettings { settings }

    func update(_ transform: @Sendable (inout RawAudioSettings) -> Void) {
        transform(&settings)
        fileStorage.write(settings, at: Self.path)
    }
}
