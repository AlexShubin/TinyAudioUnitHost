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
        Window("Tiny Audio Unit Host", id: "host") {
            WithTestsDisabled {
                MainWindowView(viewModel: dependencies.makeMainWindowViewModel())
            }
        }
        .windowResizability(.contentSize)
        .commands {
            AppCommands(viewModel: dependencies.makeAppCommandsViewModel())
        }

        Settings {
            SettingsView(viewModel: dependencies.makeSettingsViewModel())
        }

        Window("Tiny Audio Unit Host Pro", id: "purchases") {
            PurchasesView(viewModel: dependencies.makePurchasesViewModel())
        }
        .windowResizability(.contentSize)
    }
}

private struct WithTestsDisabled<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
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
