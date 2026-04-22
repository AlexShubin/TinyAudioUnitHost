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
    case setChannel(AudioInputChannel, isOn: Bool)
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
            state.selectedChannels = []
        case .setChannel(let channel, let isOn):
            if isOn {
                state.selectedChannels.insert(channel)
            } else {
                state.selectedChannels.remove(channel)
            }
        }
    }
}
