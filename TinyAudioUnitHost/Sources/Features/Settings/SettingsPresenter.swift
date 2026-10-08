//
//  SettingsPresenter.swift
//  TinyAudioUnitHost
//
//  Created by Alex Shubin on 19.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioSettingsKit

@MainActor
protocol SettingsPresenterType {
    var inputState: DevicePickerState { get }
    var outputState: DevicePickerState { get }
    var midiState: MidiDevicePickerState { get }
    var bufferSize: UInt32? { get }
    var availableBufferSizes: [UInt32] { get }
    var sampleRate: Float64? { get }
    var availableSampleRates: [Float64] { get }
    func handleInput(_ action: DevicePickerViewAction) async
    func handleOutput(_ action: DevicePickerViewAction) async
    func handleMidi(_ action: MidiDevicePickerViewAction) async
    func selectBufferSize(_ size: UInt32) async
    func selectSampleRate(_ rate: Float64) async
}

@MainActor
struct SettingsPresenter: SettingsPresenterType {
    var inputState: DevicePickerState {
        DevicePickerState(
            devices: audioSettings.inputDevices,
            selectedDevice: settings.inputDevice,
            selectedChannel: settings.inputChannel
        )
    }

    var outputState: DevicePickerState {
        DevicePickerState(
            devices: audioSettings.outputDevices,
            selectedDevice: settings.outputDevice,
            selectedChannel: settings.outputChannel
        )
    }

    var midiState: MidiDevicePickerState {
        MidiDevicePickerState(
            devices: audioSettings.midiDevices,
            selectedDevices: settings.selectedMidiDevices
        )
    }

    var bufferSize: UInt32? { settings.bufferSize }
    var availableBufferSizes: [UInt32] { audioSettings.targetDevice?.availableBufferSizes ?? [] }
    var sampleRate: Float64? { settings.sampleRate }
    var availableSampleRates: [Float64] { audioSettings.targetDevice?.availableSampleRates ?? [] }

    private let audioSettings: AudioSettingsModelType

    private var settings: AudioSettings { audioSettings.settings }

    init(audioSettings: AudioSettingsModelType) {
        self.audioSettings = audioSettings
    }

    func handleInput(_ action: DevicePickerViewAction) async {
        await handle(action, kind: .input)
    }

    func handleOutput(_ action: DevicePickerViewAction) async {
        await handle(action, kind: .output)
    }

    func handleMidi(_ action: MidiDevicePickerViewAction) async {
        switch action {
        case let .setDevice(device, isOn):
            var updated = settings
            if isOn {
                updated.selectedMidiDevices.insert(device)
            } else {
                updated.selectedMidiDevices.remove(device)
            }
            await audioSettings.save(updated)
        }
    }

    func selectBufferSize(_ size: UInt32) async {
        guard bufferSize != size else { return }
        var updated = settings
        updated.bufferSize = size
        await audioSettings.save(updated)
    }

    func selectSampleRate(_ rate: Float64) async {
        guard sampleRate != rate else { return }
        var updated = settings
        updated.sampleRate = rate
        await audioSettings.save(updated)
    }

    private func handle(_ action: DevicePickerViewAction, kind: DevicePickerKind) async {
        var updated = settings
        switch action {
        case .selectDevice(let device):
            guard updated[device: kind] != device else { return }
            updated[device: kind] = device
            updated[channel: kind] = nil
        case let .setChannel(channel, isOn):
            var selected = updated[channel: kind]?.channels ?? []
            if isOn && selected.count < 2 {
                selected.append(channel)
                selected.sort { $0.id < $1.id }
            } else {
                selected.removeAll { $0 == channel }
            }
            updated[channel: kind] = SelectedChannel(from: selected)
        }
        await audioSettings.save(updated)
    }
}

private extension AudioSettings {
    subscript(device kind: DevicePickerKind) -> AudioDevice? {
        get {
            switch kind {
            case .input: inputDevice
            case .output: outputDevice
            }
        }
        set {
            switch kind {
            case .input: inputDevice = newValue
            case .output: outputDevice = newValue
            }
        }
    }

    subscript(channel kind: DevicePickerKind) -> SelectedChannel? {
        get {
            switch kind {
            case .input: inputChannel
            case .output: outputChannel
            }
        }
        set {
            switch kind {
            case .input: inputChannel = newValue
            case .output: outputChannel = newValue
            }
        }
    }
}
