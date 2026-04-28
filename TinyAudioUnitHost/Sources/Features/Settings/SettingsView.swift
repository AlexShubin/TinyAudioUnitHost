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
}

struct SettingsView: View {
    @State var viewModel: SettingsViewModelType

    var body: some View {
        VStack {
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
        }
        .task { await viewModel.accept(action: .task) }
    }
}
