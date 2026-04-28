//
//  DevicePickerView.swift
//  TinyAudioUnitHost
//
//  Created by Alex Shubin on 23.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import Common
import SwiftUI

enum DevicePickerKind: Sendable, Hashable {
    case input
    case output
}

enum DevicePickerViewAction {
    case selectDevice(AudioDevice)
    case setChannel(AudioChannel, isOn: Bool)
}

struct DevicePickerView: View {
    let kind: DevicePickerKind
    let devices: [AudioDevice]
    let selectedDevice: AudioDevice?
    let selectedChannel: SelectedChannel?
    let onAction: (DevicePickerViewAction) -> Void

    var body: some View {
        Picker(
            deviceLabel,
            selection: Binding<AudioDevice?>(
                get: { selectedDevice },
                set: { device in
                    guard let device else { return }
                    onAction(.selectDevice(device))
                }
            )
        ) {
            ForEach(devices) { device in
                Text(device.name).tag(Optional(device))
            }
        }

        if let device = selectedDevice {
            Section(channelsLabel) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(channels(for: device)) { channel in
                            let selected = selectedChannel?.channels ?? []
                            Toggle(
                                channel.name,
                                isOn: Binding(
                                    get: { selected.contains(channel) },
                                    set: { isOn in
                                        onAction(.setChannel(channel, isOn: isOn))
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
        switch kind {
        case .input: "Audio Input Device:"
        case .output: "Audio Output Device:"
        }
    }

    private var channelsLabel: String {
        switch kind {
        case .input: "Audio Input Channels"
        case .output: "Audio Output Channels"
        }
    }

    private func channels(for device: AudioDevice) -> [AudioChannel] {
        switch kind {
        case .input: device.inputChannels
        case .output: device.outputChannels
        }
    }
}
