//
//  DevicePickerViewModel.swift
//  TinyAudioUnitHost
//
//  Created by Alex Shubin on 22.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import Observation

enum DevicePickerViewModelAction {
    case task
    case selectDevice(AudioDevice)
    case setChannel(AudioChannel, isOn: Bool)
}

@MainActor
protocol DevicePickerViewModelType: Observable {
    var state: DevicePickerViewState { get }
    func accept(action: DevicePickerViewModelAction) async
}

@MainActor @Observable
final class DevicePickerViewModel: DevicePickerViewModelType {
    private(set) var state: DevicePickerViewState

    @ObservationIgnored private let kind: DevicePickerKind
    @ObservationIgnored private let devicesProvider: AudioDevicesProviderType
    @ObservationIgnored private let settingsStore: AudioSettingsStoreType
    @ObservationIgnored private let engine: AudioUnitHostEngineType

    init(
        kind: DevicePickerKind,
        devicesProvider: AudioDevicesProviderType,
        settingsStore: AudioSettingsStoreType,
        engine: AudioUnitHostEngineType
    ) {
        self.kind = kind
        self.devicesProvider = devicesProvider
        self.settingsStore = settingsStore
        self.engine = engine
        self.state = .initial(kind: kind)
    }

    func accept(action: DevicePickerViewModelAction) async {
        switch action {
        case .task:
            state.devices = devicesProvider.devices()
            let stored = await settingsStore.current()
            if let storedDevice = storedDevice(in: stored), state.devices.contains(storedDevice) {
                state.selectedDevice = storedDevice
                state.selectedChannel = storedChannel(in: stored)
            } else {
                state.selectedDevice = state.devices.first
            }
            await pushToEngine()
        case .selectDevice(let device):
            guard state.selectedDevice != device else { return }
            state.selectedDevice = device
            state.selectedChannel = nil
            await persist()
            await pushToEngine()
        case let .setChannel(channel, isOn):
            var selected = state.selectedChannel?.channels ?? []
            if isOn && selected.count < 2 {
                selected.append(channel)
                selected.sort { $0.id < $1.id }
            } else {
                selected.removeAll { $0 == channel }
            }
            state.selectedChannel = SelectedChannel(from: selected)
            await persist()
            await pushToEngine()
        }
    }

    private func storedDevice(in settings: AudioSettings) -> AudioDevice? {
        switch kind {
        case .input: settings.inputDevice
        case .output: nil
        }
    }

    private func storedChannel(in settings: AudioSettings) -> SelectedChannel? {
        switch kind {
        case .input: settings.selectedInputChannel
        case .output: nil
        }
    }

    private func persist() async {
        switch kind {
        case .input:
            await settingsStore.update(
                AudioSettings(
                    inputDevice: state.selectedDevice,
                    selectedInputChannel: state.selectedChannel
                )
            )
        case .output:
            break
        }
    }

    private func pushToEngine() async {
        switch kind {
        case .input:
            await engine.setSelectedInputChannel(state.selectedChannel)
        case .output:
            break
        }
    }
}
