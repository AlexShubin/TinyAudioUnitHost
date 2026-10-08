//
//  SettingsView.swift
//  TinyAudioUnitHost
//
//  Created by Alex Shubin on 22.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import SwiftUI

struct SettingsView: View {
    @State var presenter: SettingsPresenter

    var body: some View {
        ScrollView {
            HStack(alignment: .top) {
                Form {
                    DevicePickerView(
                        kind: .input,
                        state: presenter.inputState,
                        onAction: { action in
                            Task { await presenter.handleInput(action) }
                        }
                    )
                    MidiDevicePickerView(
                        state: presenter.midiState,
                        onAction: { action in
                            Task { await presenter.handleMidi(action) }
                        }
                    )
                }
                .formStyle(.grouped)
                .scrollDisabled(true)
                Form {
                    DevicePickerView(
                        kind: .output,
                        state: presenter.outputState,
                        onAction: { action in
                            Task { await presenter.handleOutput(action) }
                        }
                    )
                    Picker(
                        "Sample Rate:",
                        selection: Binding<Float64?>(
                            get: { presenter.sampleRate },
                            set: { rate in
                                guard let rate else { return }
                                Task { await presenter.selectSampleRate(rate) }
                            }
                        )
                    ) {
                        ForEach(presenter.availableSampleRates, id: \.self) { rate in
                            Text(formatSampleRate(rate)).tag(Optional(rate))
                        }
                    }
                    .disabled(presenter.availableSampleRates.isEmpty)
                    Picker(
                        "Buffer Size:",
                        selection: Binding<UInt32?>(
                            get: { presenter.bufferSize },
                            set: { size in
                                guard let size else { return }
                                Task { await presenter.selectBufferSize(size) }
                            }
                        )
                    ) {
                        ForEach(presenter.availableBufferSizes, id: \.self) { size in
                            Text("\(size)").tag(Optional(size))
                        }
                    }
                    .disabled(presenter.availableBufferSizes.isEmpty)
                }
                .formStyle(.grouped)
                .scrollDisabled(true)
            }
        }
        .scrollDisabled(true)
    }

    private func formatSampleRate(_ rate: Float64) -> String {
        let kHz = rate / 1000
        return kHz == kHz.rounded() ? "\(Int(kHz)) kHz" : String(format: "%.1f kHz", kHz)
    }
}
