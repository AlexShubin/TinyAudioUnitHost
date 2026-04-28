//
//  SettingsViewModel.swift
//  TinyAudioUnitHost
//
//  Created by Alex Shubin on 22.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import Common
import EngineKit
import Observation
import StorageKit

@MainActor
protocol SettingsViewModelType: Observable {
    var inputDevices: [AudioDevice] { get }
    var inputSelectedDevice: AudioDevice? { get }
    var inputSelectedChannel: SelectedChannel? { get }
    var outputDevices: [AudioDevice] { get }
    var outputSelectedDevice: AudioDevice? { get }
    var outputSelectedChannel: SelectedChannel? { get }
    var target: TargetAudioDevice? { get }
    func accept(action: SettingsViewAction) async
}

@MainActor @Observable
final class SettingsViewModel: SettingsViewModelType {
    private(set) var inputDevices: [AudioDevice] = []
    private(set) var inputSelectedDevice: AudioDevice?
    private(set) var inputSelectedChannel: SelectedChannel?
    private(set) var outputDevices: [AudioDevice] = []
    private(set) var outputSelectedDevice: AudioDevice?
    private(set) var outputSelectedChannel: SelectedChannel?
    private(set) var target: TargetAudioDevice?

    @ObservationIgnored private let devicesProvider: AudioDevicesProviderType
    @ObservationIgnored private let settingsStore: AudioSettingsStoreType
    @ObservationIgnored private let engine: AudioUnitEngineManagerType
    @ObservationIgnored private let aggregateDeviceManager: AggregateDeviceManagerType

    init(
        devicesProvider: AudioDevicesProviderType,
        settingsStore: AudioSettingsStoreType,
        engine: AudioUnitEngineManagerType,
        aggregateDeviceManager: AggregateDeviceManagerType
    ) {
        self.devicesProvider = devicesProvider
        self.settingsStore = settingsStore
        self.engine = engine
        self.aggregateDeviceManager = aggregateDeviceManager
    }

    func accept(action: SettingsViewAction) async {
        switch action {
        case .task:
            let inputLoaded = await loadInitial(kind: .input)
            let outputLoaded = await loadInitial(kind: .output)
            if inputLoaded || outputLoaded {
                await applyToEngine()
            }
        case .inputDevicePickerAction(let pickerAction):
            await handle(pickerAction, kind: .input)
        case .outputDevicePickerAction(let pickerAction):
            await handle(pickerAction, kind: .output)
        }
    }

    private func loadInitial(kind: DevicePickerKind) async -> Bool {
        let devices = devicesProvider.devices(filter(for: kind))
        setDevices(devices, kind: kind)
        guard selectedDevice(kind: kind) == nil else { return false }
        let stored = slice(in: await settingsStore.current(), kind: kind)
        if let storedDevice = stored.device, devices.contains(storedDevice) {
            setSelectedDevice(storedDevice, kind: kind)
            setSelectedChannel(stored.selectedChannel, kind: kind)
        } else {
            setSelectedDevice(devices.first, kind: kind)
        }
        return true
    }

    private func handle(_ action: DevicePickerViewAction, kind: DevicePickerKind) async {
        switch action {
        case .selectDevice(let device):
            guard selectedDevice(kind: kind) != device else { return }
            setSelectedDevice(device, kind: kind)
            setSelectedChannel(nil, kind: kind)
            await persist(kind: kind)
            await applyToEngine()
        case let .setChannel(channel, isOn):
            var selected = selectedChannel(kind: kind)?.channels ?? []
            if isOn && selected.count < 2 {
                selected.append(channel)
                selected.sort { $0.id < $1.id }
            } else {
                selected.removeAll { $0 == channel }
            }
            setSelectedChannel(SelectedChannel(from: selected), kind: kind)
            await persist(kind: kind)
            await applyToEngine()
        }
    }

    private func selectedDevice(kind: DevicePickerKind) -> AudioDevice? {
        switch kind {
        case .input: inputSelectedDevice
        case .output: outputSelectedDevice
        }
    }

    private func selectedChannel(kind: DevicePickerKind) -> SelectedChannel? {
        switch kind {
        case .input: inputSelectedChannel
        case .output: outputSelectedChannel
        }
    }

    private func setDevices(_ devices: [AudioDevice], kind: DevicePickerKind) {
        switch kind {
        case .input: inputDevices = devices
        case .output: outputDevices = devices
        }
    }

    private func setSelectedDevice(_ device: AudioDevice?, kind: DevicePickerKind) {
        switch kind {
        case .input: inputSelectedDevice = device
        case .output: outputSelectedDevice = device
        }
    }

    private func setSelectedChannel(_ channel: SelectedChannel?, kind: DevicePickerKind) {
        switch kind {
        case .input: inputSelectedChannel = channel
        case .output: outputSelectedChannel = channel
        }
    }

    private func filter(for kind: DevicePickerKind) -> AudioDeviceFilter {
        switch kind {
        case .input: .input
        case .output: .output
        }
    }

    private func slice(in settings: AudioSettings, kind: DevicePickerKind) -> DeviceSettings {
        switch kind {
        case .input: settings.input
        case .output: settings.output
        }
    }

    private func persist(kind: DevicePickerKind) async {
        let device = selectedDevice(kind: kind)
        let channel = selectedChannel(kind: kind)
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

    private func applyToEngine() async {
        await engine.reload()
        target = await aggregateDeviceManager.resolveTarget()
    }
}
