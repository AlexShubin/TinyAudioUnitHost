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
    case selectDevice(AudioInputDevice)
    case setChannel(AudioInputDevice.InputChannel, isOn: Bool)
}

@MainActor
protocol SettingsViewModelType: Observable {
    var state: SettingsViewState { get }
    func accept(action: SettingsViewModelAction) async
}

@MainActor @Observable
final class SettingsViewModel: SettingsViewModelType {
    private(set) var state = SettingsViewState.initial

    @ObservationIgnored private let devicesProvider: AudioInputDevicesProviderType

    init(devicesProvider: AudioInputDevicesProviderType) {
        self.devicesProvider = devicesProvider
    }

    func accept(action: SettingsViewModelAction) async {
        switch action {
        case .task:
            state.devices = devicesProvider.inputDevices()
            if state.selectedDevice == nil {
                state.selectedDevice = state.devices.first
            }
        case .selectDevice(let device):
            guard state.selectedDevice != device else { return }
            state.selectedDevice = device
            state.selectedInputChannel = nil
        case let .setChannel(channel, isOn):
            var selected = state.selectedInputChannel?.channels ?? []

            if isOn && selected.count < 2 {
                selected.append(channel.id)
                selected.sort()
            } else {
                selected.removeAll { $0 == channel.id }
            }

            state.selectedInputChannel = .init(from: selected)
        }
    }
}
