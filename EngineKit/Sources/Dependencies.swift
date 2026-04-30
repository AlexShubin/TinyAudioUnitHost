//
//  Dependencies.swift
//  EngineKit
//
//  Created by Alex Shubin on 27.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AVFoundation
import StorageKit

public struct Dependencies: Sendable {
    public let audioDevicesProvider: AudioDevicesProviderType
    public let audioUnitEngineManager: AudioUnitEngineManagerType
    public let audioUnitComponentsLibrary: AudioUnitComponentsLibraryType
    public let aggregateDeviceManager: AggregateDeviceManagerType

    public static let live: Dependencies = {
        let devicesProvider = AudioDevicesProvider()
        let settingsStore = StorageKit.Dependencies.live.audioSettingsStore
        let aggregateDeviceManager = AggregateDeviceManager(
            devicesProvider: devicesProvider,
            settingsStore: settingsStore,
            factory: AggregateDeviceFactory(devicesProvider: devicesProvider)
        )
        return Dependencies(
            audioDevicesProvider: devicesProvider,
            audioUnitEngineManager: AudioUnitEngineManager(
                engine: AVAudioEngine(),
                inputMixer: AVAudioMixerNode(),
                avAudioUnitFactory: AVAudioUnitFactory(),
                coreAudioGateway: CoreAudioGateway(),
                coreMidiManager: CoreMidiManager(),
                settingsStore: settingsStore,
                aggregateDeviceManager: aggregateDeviceManager
            ),
            audioUnitComponentsLibrary: AudioUnitComponentsLibrary(),
            aggregateDeviceManager: aggregateDeviceManager
        )
    }()
}
