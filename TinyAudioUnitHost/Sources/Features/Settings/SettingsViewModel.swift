//
//  SettingsViewModel.swift
//  TinyAudioUnitHost
//
//  Created by Alex Shubin on 22.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioSettingsKit
import EngineKit
import Observation

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

    @ObservationIgnored private let audioSettings: AudioSettingsProviderType
    @ObservationIgnored private let targetSettings: TargetSettingsProviderType
    @ObservationIgnored private let devicesProvider: AudioDevicesProviderType
    @ObservationIgnored private let engine: EngineType
    @ObservationIgnored private let setupChecker: SetupCheckerType

    init(
        audioSettings: AudioSettingsProviderType,
        targetSettings: TargetSettingsProviderType,
        devicesProvider: AudioDevicesProviderType,
        engine: EngineType,
        setupChecker: SetupCheckerType
    ) {
        self.audioSettings = audioSettings
        self.targetSettings = targetSettings
        self.devicesProvider = devicesProvider
        self.engine = engine
        self.setupChecker = setupChecker
    }

    func accept(action: SettingsViewAction) async {
        switch action {
        case .task:
            let current = await audioSettings.current()
            inputState = makePickerState(kind: .input, settings: current)
            outputState = makePickerState(kind: .output, settings: current)
            bufferSize = current.bufferSize
            sampleRate = current.sampleRate
            let target = await targetSettings.resolveTarget()
            await refreshSampleRate(target: target)
            await refreshBufferSize(target: target)
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

    private func makePickerState(kind: DevicePickerKind, settings: AudioSettings) -> DevicePickerState {
        switch kind {
        case .input:
            DevicePickerState(
                devices: devicesProvider.devices(.input),
                selectedDevice: settings.inputDevice,
                selectedChannel: settings.inputChannel
            )
        case .output:
            DevicePickerState(
                devices: devicesProvider.devices(.output),
                selectedDevice: settings.outputDevice,
                selectedChannel: settings.outputChannel
            )
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

    private func persist() async {
        let input = inputState
        let output = outputState
        let buffer = bufferSize
        let rate = sampleRate
        await audioSettings.update { settings in
            settings.inputDevice = input.selectedDevice
            settings.inputChannel = input.selectedChannel
            settings.outputDevice = output.selectedDevice
            settings.outputChannel = output.selectedChannel
            settings.bufferSize = buffer
            settings.sampleRate = rate
        }
    }

    private func applyToEngine() async {
        try? await engine.reload()
        let target = await targetSettings.resolveTarget()
        await refreshSampleRate(target: target)
        await refreshBufferSize(target: target)
        await setupChecker.refresh()
    }

    private func refreshBufferSize(target: TargetSettings?) async {
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

    private func refreshSampleRate(target: TargetSettings?) async {
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
