//
//  MidiDevicePickerView.swift
//  TinyAudioUnitHost
//
//  Created by Alex Shubin on 24.07.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioSettingsKit
import SwiftUI

struct MidiDevicePickerView: View {
    let state: MidiDevicePickerState
    let onAction: (MidiDevicePickerViewAction) -> Void

    var body: some View {
        Section {
            if state.devices.isEmpty {
                Text("No MIDI devices detected.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(state.devices) { device in
                            Toggle(
                                device.name,
                                isOn: Binding(
                                    get: { state.selectedDevices.contains(device) },
                                    set: { isOn in
                                        onAction(.setDevice(device, isOn: isOn))
                                    }
                                )
                            )
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: 80)
            }
        } header: {
            Text("MIDI Input Devices")
        }
    }
}

enum MidiDevicePickerViewAction {
    case setDevice(MidiDevice, isOn: Bool)
}

struct MidiDevicePickerState: Sendable, Equatable {
    var devices: [MidiDevice]
    var selectedDevices: Set<MidiDevice>

    static let empty = MidiDevicePickerState(devices: [], selectedDevices: [])
}
