//
//  RawSettingsStore.swift
//  StorageKit
//
//  Created by Alex Shubin on 22.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

public protocol RawSettingsStoreType: Sendable {
    var current: RawAudioSettings { get }
    func update(_ transform: (inout RawAudioSettings) -> Void)
}

struct RawSettingsStore: RawSettingsStoreType {
    private static let path = "audio_settings"
    private let fileStorage: FileStorageType

    init(fileStorage: FileStorageType) {
        self.fileStorage = fileStorage
    }

    var current: RawAudioSettings {
        fileStorage.read(RawAudioSettings.self, at: Self.path) ?? .empty
    }

    func update(_ transform: (inout RawAudioSettings) -> Void) {
        var settings = current
        transform(&settings)
        fileStorage.write(settings, at: Self.path)
    }
}
