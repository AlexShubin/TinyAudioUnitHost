//
//  Dependencies.swift
//  EngineKit
//
//  Created by Alex Shubin on 27.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import StorageKit

public struct Dependencies: Sendable {
    public let audioDevicesProvider: AudioDevicesProviderType
    public let audioUnitEngineManager: AudioUnitEngineManagerType
    public let audioUnitComponentsLibrary: AudioUnitComponentsLibraryType

    public static let live: Dependencies = {
        let devicesProvider = AudioDevicesProvider()
        let engine = AudioUnitEngine(coreMidiManager: CoreMidiManager())
        let aggregateDeviceManager = AggregateDeviceManager(devicesProvider: devicesProvider)
        return Dependencies(
            audioDevicesProvider: devicesProvider,
            audioUnitEngineManager: AudioUnitEngineManager(
                engine: engine,
                settingsStore: StorageKit.Dependencies.live.audioSettingsStore,
                aggregateDeviceManager: aggregateDeviceManager
            ),
            audioUnitComponentsLibrary: AudioUnitComponentsLibrary()
        )
    }()
}
