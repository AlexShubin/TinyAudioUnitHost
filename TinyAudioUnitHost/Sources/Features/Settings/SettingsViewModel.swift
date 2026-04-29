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
    var inputState: DevicePickerState { get }
    var outputState: DevicePickerState { get }
    var bufferSize: UInt32? { get }
    var availableBufferSizes: [UInt32] { get }
    func accept(action: SettingsViewAction) async
}

@MainActor @Observable
final class SettingsViewModel: SettingsViewModelType {
    private(set) var inputState: DevicePickerState = .empty
    private(set) var outputState: DevicePickerState = .empty
    private(set) var bufferSize: UInt32?
    private(set) var availableBufferSizes: [UInt32] = []

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
            bufferSize = await settingsStore.current().bufferSize
            if inputLoaded || outputLoaded {
                await applyToEngine()
            }
        case .inputDevicePickerAction(let pickerAction):
            await handle(pickerAction, kind: .input)
        case .outputDevicePickerAction(let pickerAction):
            await handle(pickerAction, kind: .output)
        case .selectBufferSize(let size):
            guard bufferSize != size else { return }
            bufferSize = size
            await persist()
            await applyToEngine()
        }
    }

    private func loadInitial(kind: DevicePickerKind) async -> Bool {
        let devices = devicesProvider.devices(filter(for: kind))
        mutatePickerState(kind: kind) { $0.devices = devices }
        guard pickerState(kind: kind).selectedDevice == nil else { return false }
        let stored = slice(in: await settingsStore.current(), kind: kind)
        mutatePickerState(kind: kind) { state in
            if let storedDevice = stored.device, devices.contains(storedDevice) {
                state.selectedDevice = storedDevice
                state.selectedChannel = stored.selectedChannel
            }
        }
        return true
    }

    private func handle(_ action: DevicePickerViewAction, kind: DevicePickerKind) async {
        switch action {
        case .selectDevice(let device):
            guard pickerState(kind: kind).selectedDevice != device else { return }
            mutatePickerState(kind: kind) { state in
                state.selectedDevice = device
                state.selectedChannel = nil
            }
            await persist()
            await applyToEngine()
        case let .setChannel(channel, isOn):
            mutatePickerState(kind: kind) { state in
                var selected = state.selectedChannel?.channels ?? []
                if isOn && selected.count < 2 {
                    selected.append(channel)
                    selected.sort { $0.id < $1.id }
                } else {
                    selected.removeAll { $0 == channel }
                }
                state.selectedChannel = SelectedChannel(from: selected)
            }
            await persist()
            await applyToEngine()
        }
    }

    private func pickerState(kind: DevicePickerKind) -> DevicePickerState {
        switch kind {
        case .input: inputState
        case .output: outputState
        }
    }

    private func mutatePickerState(kind: DevicePickerKind, _ mutate: (inout DevicePickerState) -> Void) {
        switch kind {
        case .input: mutate(&inputState)
        case .output: mutate(&outputState)
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

    private func persist() async {
        let input = inputState
        let output = outputState
        let buffer = bufferSize
        await settingsStore.update { settings in
            settings.input.device = input.selectedDevice
            settings.input.selectedChannel = input.selectedChannel
            settings.output.device = output.selectedDevice
            settings.output.selectedChannel = output.selectedChannel
            settings.bufferSize = buffer
        }
    }

    private func applyToEngine() async {
        await engine.reload()
        let target = await aggregateDeviceManager.resolveTarget()
        await refreshBufferSize(target: target)
    }

    private func refreshBufferSize(target: TargetAudioDevice?) async {
        availableBufferSizes = target?.device.availableBufferSizes ?? []
        let resolved = resolveBufferSize(current: bufferSize, available: availableBufferSizes)
        guard resolved != bufferSize else { return }
        bufferSize = resolved
        await persist()
    }

    private func resolveBufferSize(current: UInt32?, available: [UInt32]) -> UInt32? {
        guard !available.isEmpty else { return nil }
        if let current, available.contains(current) { return current }
        if let current {
            return available.min { left, right in
                abs(Int64(left) - Int64(current)) < abs(Int64(right) - Int64(current))
            }
        }
        return available.contains(256) ? 256 : available.first
    }
}
