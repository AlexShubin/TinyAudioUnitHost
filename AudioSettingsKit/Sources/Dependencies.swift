//
//  Dependencies.swift
//  AudioSettingsKit
//
//  Created by Alex Shubin on 02.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import StorageKit

public struct Dependencies: Sendable {
    public let facade: AudioSettingsFacadeType
    public let aggregateDeviceManager: AggregateDeviceManagerType
    public let devicesProvider: AudioDevicesProviderType

    public static let live: Dependencies = {
        let devicesProvider = AudioDevicesProvider()
        let rawStore = StorageKit.Dependencies.live.rawSettingsStore
        let facade = AudioSettingsFacade(rawStore: rawStore, devicesProvider: devicesProvider)
        let aggregateDeviceManager = AggregateDeviceManager(
            facade: facade,
            devicesProvider: devicesProvider
        )
        return Dependencies(
            facade: facade,
            aggregateDeviceManager: aggregateDeviceManager,
            devicesProvider: devicesProvider
        )
    }()
}
