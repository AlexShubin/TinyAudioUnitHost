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
            HStack {
                DevicePickerView(viewState: viewModel.state.inputDevicePciker)
                DevicePickerView(viewState: viewModel.state.outputDevicePciker)
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
    var inputDevicePciker: DevicePickerViewState
    var outputDevicePciker: DevicePickerViewState

    static var initial: Self {
        .init(inputDevicePciker: .initial, outputDevicePciker: .initial)
    }
}
