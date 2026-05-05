//
//  Dependencies.swift
//  StorageKit
//
//  Created by Alex Shubin on 27.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

public struct Dependencies: Sendable {
    public let rawSettingsStore: RawSettingsStoreType
    public let rawPresetStore: RawPresetStoreType

    public static let live = Dependencies(
        rawSettingsStore: RawSettingsStore(fileStorage: FileStorage()),
        rawPresetStore: RawPresetStore(fileStorage: FileStorage())
    )
}
