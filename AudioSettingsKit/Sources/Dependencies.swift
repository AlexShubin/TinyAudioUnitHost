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
    public let targetSettingsProvider: TargetSettingsProviderType
    public let devicesProvider: AudioDevicesProviderType

    public static let live: Dependencies = {
        let devicesProvider = AudioDevicesProvider()
        let rawStore = StorageKit.Dependencies.live.rawSettingsStore
        let facade = AudioSettingsFacade(rawStore: rawStore, devicesProvider: devicesProvider)
        let targetSettingsProvider = TargetSettingsProvider(
            facade: facade,
            devicesProvider: devicesProvider
        )
        return Dependencies(
            facade: facade,
            targetSettingsProvider: targetSettingsProvider,
            devicesProvider: devicesProvider
        )
    }()
}
