//
//  TinyAudioUnitHostApp.swift
//  TinyAudioUnitHost
//
//  Created by Alex Shubin on 19.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import SwiftUI

@main
struct TinyAudioUnitHostApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @Environment(\.dependencies) private var dependencies

    var body: some Scene {
        WindowGroup {
            withTestsDisabled {
                HostView(viewModel: dependencies.makeHostViewModel())
                    .task {
                        dependencies.engine.engineReloader.startListening(to: .audioEngineConfigurationChange)
                        dependencies.engine.engineReloader.startListening(to: .workspaceDidWake)
                        dependencies.audioSettings.setupRefresher.startListening()
                    }
            }
        }
        .windowResizability(.contentSize)

        Settings {
            withTestsDisabled { SettingsView(viewModel: dependencies.makeSettingsViewModel()) }
        }
    }

    @ViewBuilder
    private func withTestsDisabled<V: View>(@ViewBuilder _ content: () -> V) -> some View {
        if isRunningTests {
            EmptyView()
        } else {
            content()
        }
    }

    private var isRunningTests: Bool {
        NSClassFromString("XCTestCase") != nil
    }
}
