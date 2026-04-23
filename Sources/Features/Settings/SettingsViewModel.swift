//
//  SettingsViewModel.swift
//  TinyAudioUnitHost
//
//  Created by Alex Shubin on 22.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import Observation

@MainActor
protocol SettingsViewModelType: Observable {
    var inputDevicePicker: DevicePickerViewModelType { get }
    var outputDevicePicker: DevicePickerViewModelType { get }
}

@MainActor @Observable
final class SettingsViewModel: SettingsViewModelType {
    let inputDevicePicker: DevicePickerViewModelType
    let outputDevicePicker: DevicePickerViewModelType

    init(
        devicesProvider: AudioDevicesProviderType,
        settingsStore: AudioSettingsStoreType,
        engine: AudioUnitHostEngineType
    ) {
        self.inputDevicePicker = DevicePickerViewModel(
            kind: .input,
            devicesProvider: devicesProvider,
            settingsStore: settingsStore,
            engine: engine
        )
        self.outputDevicePicker = DevicePickerViewModel(
            kind: .output,
            devicesProvider: devicesProvider,
            settingsStore: settingsStore,
            engine: engine
        )
    }
}
