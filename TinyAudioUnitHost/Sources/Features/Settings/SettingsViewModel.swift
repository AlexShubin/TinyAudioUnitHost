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
    var sampleRate: Float64? { get }
    var availableSampleRates: [Float64] { get }
    func accept(action: SettingsViewAction) async
}

@MainActor @Observable
final class SettingsViewModel: SettingsViewModelType {
    private(set) var inputState: DevicePickerState = .empty
    private(set) var outputState: DevicePickerState = .empty
    private(set) var bufferSize: UInt32?
    private(set) var availableBufferSizes: [UInt32] = []
    private(set) var sampleRate: Float64?
    private(set) var availableSampleRates: [Float64] = []

    @ObservationIgnored private let devicesProvider: AudioDevicesProviderType
    @ObservationIgnored private let settingsStore: AudioSettingsStoreType
    @ObservationIgnored private let engine: EngineType
    @ObservationIgnored private let aggregateDeviceManager: AggregateDeviceManagerType

    init(
        devicesProvider: AudioDevicesProviderType,
        settingsStore: AudioSettingsStoreType,
        engine: EngineType,
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
            await loadInitial(kind: .input)
            await loadInitial(kind: .output)
            let current = await settingsStore.current()
            bufferSize = current.bufferSize
            sampleRate = current.sampleRate
            await applyToEngine()
        case .inputDevicePickerAction(let pickerAction):
            await handle(pickerAction, kind: .input)
        case .outputDevicePickerAction(let pickerAction):
            await handle(pickerAction, kind: .output)
        case .selectBufferSize(let size):
            guard bufferSize != size else { return }
            bufferSize = size
            await persist()
            await applyToEngine()
        case .selectSampleRate(let rate):
            guard sampleRate != rate else { return }
            sampleRate = rate
            await persist()
            await applyToEngine()
        }
    }

    private func loadInitial(kind: DevicePickerKind) async {
        let devices = devicesProvider.devices(filter(for: kind))
        let stored = slice(in: await settingsStore.current(), kind: kind)
        mutatePickerState(kind: kind) { state in
            state.devices = devices
            if let storedUID = stored.deviceUID,
               let live = devices.first(where: { $0.uid == storedUID }) {
                state.selectedDevice = live
                state.selectedChannel = stored.selectedChannelIDs.flatMap {
                    SelectedChannel(ids: $0, in: deviceChannels(live, kind: kind))
                }
            } else {
                state.selectedDevice = nil
                state.selectedChannel = nil
            }
        }
    }

    private func deviceChannels(_ device: AudioDevice, kind: DevicePickerKind) -> [AudioChannel] {
        switch kind {
        case .input: device.inputChannels
        case .output: device.outputChannels
        }
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
        let rate = sampleRate
        await settingsStore.update { settings in
            settings.input.deviceUID = input.selectedDevice?.uid
            settings.input.selectedChannelIDs = input.selectedChannel?.channels.map(\.id)
            settings.output.deviceUID = output.selectedDevice?.uid
            settings.output.selectedChannelIDs = output.selectedChannel?.channels.map(\.id)
            settings.bufferSize = buffer
            settings.sampleRate = rate
        }
    }

    private func applyToEngine() async {
        await engine.reload()
        let target = await aggregateDeviceManager.resolveTarget()
        await refreshSampleRate(target: target)
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
        return available.contains(32) ? 32 : available.first
    }

    private func refreshSampleRate(target: TargetAudioDevice?) async {
        availableSampleRates = target?.device.availableSampleRates ?? []
        let resolved = resolveSampleRate(current: sampleRate, available: availableSampleRates)
        guard resolved != sampleRate else { return }
        sampleRate = resolved
        await persist()
    }

    private func resolveSampleRate(current: Float64?, available: [Float64]) -> Float64? {
        guard !available.isEmpty else { return nil }
        if let current, available.contains(current) { return current }
        return available.contains(48_000) ? 48_000 : available.first
    }
}
