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
    var kind: DevicePickerKind { get }
    var devices: [AudioDevice] { get }
    var selectedDevice: AudioDevice? { get }
    var selectedChannel: SelectedChannel? { get }
    func accept(action: DevicePickerViewModelAction) async
}

@MainActor @Observable
final class DevicePickerViewModel: DevicePickerViewModelType {
    let kind: DevicePickerKind
    private(set) var devices: [AudioDevice] = []
    private(set) var selectedDevice: AudioDevice?
    private(set) var selectedChannel: SelectedChannel?

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
    }

    func accept(action: DevicePickerViewModelAction) async {
        switch action {
        case .task:
            devices = devicesProvider.devices().filter { !channels(in: $0).isEmpty }
            guard selectedDevice == nil else { return }
            let stored = await settingsStore.current()
            if let storedDevice = storedDevice(in: stored), devices.contains(storedDevice) {
                selectedDevice = storedDevice
                selectedChannel = storedChannel(in: stored)
            } else {
                selectedDevice = devices.first
            }
            await pushToEngine()
        case .selectDevice(let device):
            guard selectedDevice != device else { return }
            selectedDevice = device
            selectedChannel = nil
            await persist()
            await pushToEngine()
        case let .setChannel(channel, isOn):
            var selected = selectedChannel?.channels ?? []
            if isOn && selected.count < 2 {
                selected.append(channel)
                selected.sort { $0.id < $1.id }
            } else {
                selected.removeAll { $0 == channel }
            }
            selectedChannel = SelectedChannel(from: selected)
            await persist()
            await pushToEngine()
        }
    }

    private func channels(in device: AudioDevice) -> [AudioChannel] {
        switch kind {
        case .input: device.inputChannels
        case .output: device.outputChannels
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
                    inputDevice: selectedDevice,
                    selectedInputChannel: selectedChannel
                )
            )
        case .output:
            break
        }
    }

    private func pushToEngine() async {
        switch kind {
        case .input:
            await engine.setSelectedInputChannel(selectedChannel)
        case .output:
            break
        }
    }
}
