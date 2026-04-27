//
//  DevicePickerView.swift
//  TinyAudioUnitHost
//
//  Created by Alex Shubin on 23.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import Common
import SwiftUI

struct DevicePickerView: View {
    @State var viewModel: DevicePickerViewModelType

    var body: some View {
        Picker(
            deviceLabel,
            selection: Binding<AudioDevice?>(
                get: { viewModel.selectedDevice },
                set: { device in
                    guard let device else { return }
                    Task { await viewModel.accept(action: .selectDevice(device)) }
                }
            )
        ) {
            ForEach(viewModel.devices) { device in
                Text(device.name).tag(Optional(device))
            }
        }
        .task { await viewModel.accept(action: .task) }

        if let device = viewModel.selectedDevice {
            Section(channelsLabel) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(channels(for: device)) { channel in
                            let selected = viewModel.selectedChannel?.channels ?? []
                            Toggle(
                                channel.name,
                                isOn: Binding(
                                    get: { selected.contains(channel) },
                                    set: { isOn in
                                        Task { await viewModel.accept(action: .setChannel(channel, isOn: isOn)) }
                                    }
                                )
                            )
                            .disabled(selected.count == 2 && !selected.contains(channel))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: 200)
            }
        }
    }

    private var deviceLabel: String {
        switch viewModel.kind {
        case .input: "Audio Input Device:"
        case .output: "Audio Output Device:"
        }
    }
    
    private var channelsLabel: String {
        switch viewModel.kind {
        case .input: "Audio Input Channels"
        case .output: "Audio Output Channels"
        }
    }

    private func channels(for device: AudioDevice) -> [AudioChannel] {
        switch viewModel.kind {
        case .input: device.inputChannels
        case .output: device.outputChannels
        }
    }
}

enum DevicePickerKind: Sendable, Hashable {
    case input
    case output
}
