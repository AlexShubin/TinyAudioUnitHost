//
//  SettingsView.swift
//  TinyAudioUnitHost
//
//  Created by Alex Shubin on 22.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import SwiftUI

struct SettingsView: View {
    @State var viewModel: SettingsViewModelType

    var body: some View {
        Form {
            Picker(
                "Audio Input Device:",
                selection: Binding<AudioInputDevice?>(
                    get: { viewModel.state.selectedDevice },
                    set: { device in
                        guard let device else { return }
                        Task { await viewModel.accept(action: .selectDevice(device)) }
                    }
                )
            ) {
                ForEach(viewModel.state.devices) { device in
                    Text(device.name).tag(Optional(device))
                }
            }

            if let device = viewModel.state.selectedDevice {
                Section("Audio Input Channels") {
                    ForEach(device.channels) { channel in
                        Toggle(
                            channel.name,
                            isOn: Binding(
                                get: { viewModel.state.selectedChannels.contains(channel) },
                                set: { isOn in
                                    Task {
                                        await viewModel.accept(
                                            action: .setChannel(channel, isOn: isOn)
                                        )
                                    }
                                }
                            )
                        )
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 480, height: 400)
        .task {
            await viewModel.accept(action: .task)
        }
    }
}

// MARK: - View State

struct SettingsViewState {
    var devices: [AudioInputDevice]
    var selectedDevice: AudioInputDevice?
    var selectedChannels: Set<AudioInputChannel>

    static var initial: Self {
        .init(devices: [], selectedDevice: nil, selectedChannels: [])
    }
}
