//
//  Dependencies.swift
//  AudioSettingsKit
//
//  Created by Alex Shubin on 02.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import Common
import Foundation
import StorageKit

public struct Dependencies: Sendable {
    public let audioSettingsProvider: AudioSettingsProviderType
    public let targetSettingsProvider: TargetSettingsProviderType
    public let devicesProvider: AudioDevicesProviderType
    public let setupChecker: SetupCheckerType
    public let setupRefresher: SetupRefresherType

    public static let live: Dependencies = {
        let devicesProvider = AudioDevicesProvider()
        let rawStore = StorageKit.Dependencies.live.rawSettingsStore
        let audioSettingsProvider = AudioSettingsProvider(rawStore: rawStore, devicesProvider: devicesProvider)
        let targetSettingsProvider = TargetSettingsProvider(
            audioSettings: audioSettingsProvider,
            devicesProvider: devicesProvider,
            factory: AggregateDeviceFactory(devicesProvider: devicesProvider)
        )
        let setupChecker = SetupChecker(targetSettingsProvider: targetSettingsProvider)
        return Dependencies(
            audioSettingsProvider: audioSettingsProvider,
            targetSettingsProvider: targetSettingsProvider,
            devicesProvider: devicesProvider,
            setupChecker: setupChecker,
            setupRefresher: SetupRefresher(
                setupChecker: setupChecker,
                notificationCenter: NotificationCenter.default
            )
        )
    }()
}
