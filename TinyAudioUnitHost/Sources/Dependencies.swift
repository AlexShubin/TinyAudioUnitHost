//
//  Dependencies.swift
//  TinyAudioUnitHost
//
//  Created by Alex Shubin on 19.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import EngineKit
import StorageKit
import SwiftUI

struct Dependencies: Sendable {
    let storage: StorageKit.Dependencies
    let engine: EngineKit.Dependencies

    static let live: Dependencies = {
        Dependencies(storage: .live, engine: .live)
    }()

    @MainActor func makeHostViewModel() -> HostViewModelType {
        HostViewModel(
            engine: engine.audioUnitEngineManager,
            library: engine.audioUnitComponentsLibrary,
            settingsStore: storage.audioSettingsStore,
            aggregateDeviceManager: engine.aggregateDeviceManager
        )
    }

    @MainActor func makeSettingsViewModel() -> SettingsViewModelType {
        SettingsViewModel(
            devicesProvider: engine.audioDevicesProvider,
            settingsStore: storage.audioSettingsStore,
            engine: engine.audioUnitEngineManager,
            aggregateDeviceManager: engine.aggregateDeviceManager
        )
    }
}

// MARK: - Environment

extension EnvironmentValues {
    @Entry var dependencies: Dependencies = .live
}
