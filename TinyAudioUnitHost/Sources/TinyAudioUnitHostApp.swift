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
            if !isRunningTests {
                MainWindowView()
            }
        }
        .windowResizability(.contentSize)
        .commands {
            if !isRunningTests {
                AppCommands(viewModel: dependencies.makeAppCommandsViewModel())
            }
        }

        Settings {
            if !isRunningTests {
                SettingsView(viewModel: dependencies.makeSettingsViewModel())
            }
        }

        Window("Tiny Audio Unit Host Pro", id: "purchases") {
            if !isRunningTests {
                PurchasesView(viewModel: dependencies.makePurchasesViewModel())
            }
        }
        .windowResizability(.contentSize)
    }
}

var isRunningTests: Bool {
    NSClassFromString("XCTestCase") != nil
}
