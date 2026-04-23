//
//  SettingsViewModel.swift
//  TinyAudioUnitHost
//
//  Created by Alex Shubin on 22.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import Observation

enum SettingsViewModelAction {
    case task
    case selectDevice(AudioDevice)
    case setChannel(AudioChannel, isOn: Bool)
}

@MainActor
protocol SettingsViewModelType: Observable {
    var state: SettingsViewState { get }
    func accept(action: SettingsViewModelAction) async
}

@MainActor @Observable
final class SettingsViewModel: SettingsViewModelType {
    private(set) var state = SettingsViewState.initial

    @ObservationIgnored private let devicesProvider: AudioDevicesProviderType
    @ObservationIgnored private let settingsStore: AudioSettingsStoreType
    @ObservationIgnored private let engine: AudioUnitHostEngineType

    init(
        devicesProvider: AudioDevicesProviderType,
        settingsStore: AudioSettingsStoreType,
        engine: AudioUnitHostEngineType
    ) {
        self.devicesProvider = devicesProvider
        self.settingsStore = settingsStore
        self.engine = engine
    }

    func accept(action: SettingsViewModelAction) async {
        switch action {
        case .task:
            state.devices = devicesProvider.devices()
            guard state.selectedDevice == nil else { return }
            let stored = await settingsStore.current()
            if let storedDevice = stored.inputDevice, state.devices.contains(storedDevice) {
                state.selectedDevice = storedDevice
                state.selectedInputChannel = stored.selectedInputChannel
            } else {
                state.selectedDevice = state.devices.first
            }
            await pushToEngine()
        case .selectDevice(let device):
            guard state.selectedDevice != device else { return }
            state.selectedDevice = device
            state.selectedInputChannel = nil
            await persist()
            await pushToEngine()
        case let .setChannel(channel, isOn):
            var selected = state.selectedInputChannel?.channels ?? []

            if isOn && selected.count < 2 {
                selected.append(channel)
                selected.sort { $0.id < $1.id }
            } else {
                selected.removeAll { $0 == channel }
            }

            state.selectedInputChannel = .init(from: selected)
            await persist()
            await pushToEngine()
        }
    }

    private func persist() async {
        await settingsStore.update(
            AudioSettings(
                inputDevice: state.selectedDevice,
                selectedInputChannel: state.selectedInputChannel
            )
        )
    }

    private func pushToEngine() async {
        await engine.setSelectedInputChannel(state.selectedInputChannel)
    }
}
