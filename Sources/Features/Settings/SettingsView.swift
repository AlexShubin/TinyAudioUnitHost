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
        VStack(spacing: 12) {
            Image(systemName: "hammer.fill")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Under construction")
                .font(.title2)
                .foregroundStyle(.secondary)
        }
        .frame(width: 480, height: 320)
        .task {
            await viewModel.accept(action: .task)
        }
    }
}

// MARK: - View State

struct SettingsViewState {
    static var initial: Self { .init() }
}
