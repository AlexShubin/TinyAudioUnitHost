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
    @State private var viewModel: HostViewModelType?

    var body: some Scene {
        WindowGroup {
            if let viewModel {
                HostView(viewModel: viewModel)
            } else {
                Color.clear.task {
                    viewModel = dependencies.makeHostViewModel()
                    delegate.onQuit = { [persister = dependencies.sessionPersister] in
                        await persister.persistSession()
                    }
                }
            }
        }
        .windowResizability(.contentSize)

        Settings {
            SettingsView(viewModel: dependencies.makeSettingsViewModel())
        }
    }
}
