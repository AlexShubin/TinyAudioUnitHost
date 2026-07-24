//
//  MainWindowView.swift
//  TinyAudioUnitHost
//
//  Created by Alex Shubin on 22.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import SwiftUI

struct MainWindowView: View {
    @Environment(\.dependencies) private var dependencies

    var body: some View {
        NavigationSplitView {
            PresetsView(viewModel: dependencies.makePresetsViewModel())
                .navigationSplitViewColumnWidth(min: 220, ideal: 260)
        } detail: {
            HostView(viewModel: dependencies.makeHostViewModel())
        }
    }
}
