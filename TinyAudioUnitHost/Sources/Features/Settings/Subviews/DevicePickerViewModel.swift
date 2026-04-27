//
//  DevicePickerViewModel.swift
//  TinyAudioUnitHost
//
//  Created by Alex Shubin on 22.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import Common
import Observation
import StorageKit

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
    @ObservationIgnored private let engine: AudioUnitEngineManagerType

    init(
        kind: DevicePickerKind,
        devicesProvider: AudioDevicesProviderType,
        settingsStore: AudioSettingsStoreType,
        engine: AudioUnitEngineManagerType
    ) {
        self.kind = kind
        self.devicesProvider = devicesProvider
        self.settingsStore = settingsStore
        self.engine = engine
    }

    func accept(action: DevicePickerViewModelAction) async {
        switch action {
        case .task:
            devices = devicesProvider.devices(deviceFilter)
            guard selectedDevice == nil else { return }
            let stored = slice(in: await settingsStore.current())
            if let storedDevice = stored.device, devices.contains(storedDevice) {
                selectedDevice = storedDevice
                selectedChannel = stored.selectedChannel
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

    private func slice(in settings: AudioSettings) -> DeviceSettings {
        switch kind {
        case .input: settings.input
        case .output: settings.output
        }
    }

    private func persist() async {
        let kind = self.kind
        let device = selectedDevice
        let channel = selectedChannel
        await settingsStore.update { settings in
            switch kind {
            case .input:
                settings.input.device = device
                settings.input.selectedChannel = channel
            case .output:
                settings.output.device = device
                settings.output.selectedChannel = channel
            }
        }
    }

    private func pushToEngine() async {
        await engine.reconnect()
    }

    private var deviceFilter: AudioDeviceFilter {
        switch kind {
        case .input: .input
        case .output: .output
        }
    }
}
