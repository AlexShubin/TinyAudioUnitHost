//
//  Dependencies.swift
//  AudioSettingsKit
//
//  Created by Alex Shubin on 02.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import StorageKit

public struct Dependencies: Sendable {
    public let audioSettingsProvider: AudioSettingsProviderType
    public let targetSettingsProvider: TargetSettingsProviderType
    public let devicesProvider: AudioDevicesProviderType

    public static let live: Dependencies = {
        let devicesProvider = AudioDevicesProvider()
        let rawStore = StorageKit.Dependencies.live.rawSettingsStore
        let audioSettingsProvider = AudioSettingsProvider(rawStore: rawStore, devicesProvider: devicesProvider)
        let targetSettingsProvider = TargetSettingsProvider(
            audioSettings: audioSettingsProvider,
            devicesProvider: devicesProvider,
            factory: AggregateDeviceFactory(devicesProvider: devicesProvider)
        )
        return Dependencies(
            audioSettingsProvider: audioSettingsProvider,
            targetSettingsProvider: targetSettingsProvider,
            devicesProvider: devicesProvider
        )
    }()
}
