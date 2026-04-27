//
//  SettingsViewModel.swift
//  TinyAudioUnitHost
//
//  Created by Alex Shubin on 22.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import EngineKit
import Observation
import StorageKit

@MainActor
protocol SettingsViewModelType: Observable {
    var inputDevicePicker: DevicePickerViewModelType { get }
    var outputDevicePicker: DevicePickerViewModelType { get }
    var target: TargetAudioDevice? { get }
}

@MainActor @Observable
final class SettingsViewModel: SettingsViewModelType {
    let inputDevicePicker: DevicePickerViewModelType
    let outputDevicePicker: DevicePickerViewModelType
    private(set) var target: TargetAudioDevice?

    @ObservationIgnored private let settingsStore: AudioSettingsStoreType
    @ObservationIgnored private let engine: AudioUnitEngineManagerType
    @ObservationIgnored private let aggregateDeviceManager: AggregateDeviceManagerType

    init(
        devicesProvider: AudioDevicesProviderType,
        settingsStore: AudioSettingsStoreType,
        engine: AudioUnitEngineManagerType,
        aggregateDeviceManager: AggregateDeviceManagerType
    ) {
        self.settingsStore = settingsStore
        self.engine = engine
        self.aggregateDeviceManager = aggregateDeviceManager
        self.inputDevicePicker = DevicePickerViewModel(
            kind: .input,
            devicesProvider: devicesProvider,
            settingsStore: settingsStore
        )
        self.outputDevicePicker = DevicePickerViewModel(
            kind: .output,
            devicesProvider: devicesProvider,
            settingsStore: settingsStore
        )

        let apply: @MainActor () async -> Void = { [weak self] in
            await self?.applyToEngine()
        }
        inputDevicePicker.onChange = apply
        outputDevicePicker.onChange = apply
    }

    private func applyToEngine() async {
        let settings = await settingsStore.current()
        target = await aggregateDeviceManager.resolve(
            input: settings.input.device,
            output: settings.output.device
        )
        await engine.apply(
            target: target,
            input: settings.input.selectedChannel,
            output: settings.output.selectedChannel
        )
    }
}
