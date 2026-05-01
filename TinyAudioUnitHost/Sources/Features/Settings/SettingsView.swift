//
//  SettingsView.swift
//  TinyAudioUnitHost
//
//  Created by Alex Shubin on 22.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import SwiftUI

enum SettingsViewAction {
    case task
    case inputDevicePickerAction(DevicePickerViewAction)
    case outputDevicePickerAction(DevicePickerViewAction)
    case selectBufferSize(UInt32)
    case selectSampleRate(Float64)
}

struct SettingsView: View {
    @State var viewModel: SettingsViewModelType

    var body: some View {
        HStack {
            Form {
                DevicePickerView(
                    kind: .input,
                    state: viewModel.inputState,
                    onAction: { action in
                        Task { await viewModel.accept(action: .inputDevicePickerAction(action)) }
                    }
                )
                Picker(
                    "Sample Rate:",
                    selection: Binding<Float64?>(
                        get: { viewModel.sampleRate },
                        set: { rate in
                            guard let rate else { return }
                            Task { await viewModel.accept(action: .selectSampleRate(rate)) }
                        }
                    )
                ) {
                    ForEach(viewModel.availableSampleRates, id: \.self) { rate in
                        Text(formatSampleRate(rate)).tag(Optional(rate))
                    }
                }
                .disabled(viewModel.availableSampleRates.isEmpty)
                Picker(
                    "Buffer Size:",
                    selection: Binding<UInt32?>(
                        get: { viewModel.bufferSize },
                        set: { size in
                            guard let size else { return }
                            Task { await viewModel.accept(action: .selectBufferSize(size)) }
                        }
                    )
                ) {
                    ForEach(viewModel.availableBufferSizes, id: \.self) { size in
                        Text("\(size)").tag(Optional(size))
                    }
                }
                .disabled(viewModel.availableBufferSizes.isEmpty)
            }
            .formStyle(.grouped)
            Form {
                DevicePickerView(
                    kind: .output,
                    state: viewModel.outputState,
                    onAction: { action in
                        Task { await viewModel.accept(action: .outputDevicePickerAction(action)) }
                    }
                )
            }
            .formStyle(.grouped)
        }
        .task { await viewModel.accept(action: .task) }
    }

    private func formatSampleRate(_ rate: Float64) -> String {
        let kHz = rate / 1000
        return kHz == kHz.rounded() ? "\(Int(kHz)) kHz" : String(format: "%.1f kHz", kHz)
    }
}
