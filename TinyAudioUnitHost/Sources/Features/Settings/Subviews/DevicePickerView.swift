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
    case selectDevice(AudioDevice?)
    case setChannel(AudioChannel, isOn: Bool)
}

struct DevicePickerState: Sendable, Equatable {
    var devices: [AudioDevice]
    var selectedDevice: AudioDevice?
    var selectedChannel: SelectedChannel?

    static let empty = DevicePickerState(devices: [], selectedDevice: nil, selectedChannel: nil)
}

struct DevicePickerView: View {
    let kind: DevicePickerKind
    let state: DevicePickerState
    let onAction: (DevicePickerViewAction) -> Void

    var body: some View {
        Picker(
            deviceLabel,
            selection: Binding<AudioDevice?>(
                get: { state.selectedDevice },
                set: { onAction(.selectDevice($0)) }
            )
        ) {
            Text("<<none>>").tag(AudioDevice?.none)
            ForEach(state.devices) { device in
                Text(device.name).tag(Optional(device))
            }
        }

        Section(channelsLabel) {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(channels(for: state.selectedDevice)) { channel in
                        let selected = state.selectedChannel?.channels ?? []
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
            .frame(height: 100)
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

    private func channels(for device: AudioDevice?) -> [AudioChannel] {
        switch kind {
        case .input: device?.inputChannels ?? []
        case .output: device?.outputChannels ?? []
        }
    }
}
