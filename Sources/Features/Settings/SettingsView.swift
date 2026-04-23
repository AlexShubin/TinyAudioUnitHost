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
                DevicePickerView(viewModel: viewModel.inputDevicePicker)
                DevicePickerView(viewModel: viewModel.outputDevicePicker)
            }
        }
    }
}
