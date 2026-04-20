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
    @Environment(\.dependencies) private var dependencies

    var body: some Scene {
        WindowGroup {
            HostView(viewModel: dependencies.makeHostViewModel())
        }
        .windowResizability(.contentSize)
    }
}
