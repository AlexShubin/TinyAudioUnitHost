//
//  Dependencies.swift
//  EngineKit
//
//  Created by Alex Shubin on 27.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

public struct Dependencies: Sendable {
    public let audioDevicesProvider: AudioDevicesProviderType
    public let audioUnitEngineManager: AudioUnitEngineManagerType
    public let audioUnitComponentsLibrary: AudioUnitComponentsLibraryType
    public let aggregateDeviceManager: AggregateDeviceManagerType

    public static let live: Dependencies = {
        let devicesProvider = AudioDevicesProvider()
        let engine = AudioUnitEngine(coreMidiManager: CoreMidiManager())
        return Dependencies(
            audioDevicesProvider: devicesProvider,
            audioUnitEngineManager: AudioUnitEngineManager(engine: engine),
            audioUnitComponentsLibrary: AudioUnitComponentsLibrary(),
            aggregateDeviceManager: AggregateDeviceManager(devicesProvider: devicesProvider)
        )
    }()
}
