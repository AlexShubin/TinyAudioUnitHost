//
//  Dependencies.swift
//  StorageKit
//
//  Created by Alex Shubin on 27.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

public struct Dependencies: Sendable {
    public let audioSettingsStore: AudioSettingsStoreType

    public static let live = Dependencies(
        audioSettingsStore: AudioSettingsStore(fileStorage: FileStorage())
    )
}
