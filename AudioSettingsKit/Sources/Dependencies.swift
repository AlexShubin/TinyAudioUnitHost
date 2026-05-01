//
//  Dependencies.swift
//  AudioSettingsKit
//
//  Created by Alex Shubin on 02.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import StorageKit

public struct Dependencies: Sendable {
    public let repository: AudioSettingsRepositoryType
    public let devicesProvider: AudioDevicesProviderType

    public static let live: Dependencies = {
        let devicesProvider = AudioDevicesProvider()
        let rawStore = StorageKit.Dependencies.live.rawSettingsStore
        let aggregateDeviceManager = AggregateDeviceManager(
            devicesProvider: devicesProvider,
            settingsStore: rawStore
        )
        return Dependencies(
            repository: AudioSettingsRepository(
                rawStore: rawStore,
                devicesProvider: devicesProvider,
                aggregateDeviceManager: aggregateDeviceManager
            ),
            devicesProvider: devicesProvider
        )
    }()
}
