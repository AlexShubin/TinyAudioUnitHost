//
//  HostView.swift
//  TinyAudioUnitHost
//
//  Created by Alex Shubin on 19.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import SwiftUI

struct HostView: View {
    @State var viewModel: HostViewModelType

    var body: some View {
        NavigationSplitView {
            List(
                viewModel.state.components,
                selection: Binding(
                    get: { viewModel.state.selectedComponent },
                    set: { component in
                        if let component {
                            Task { await viewModel.accept(action: .selected(component)) }
                        }
                    }
                )
            ) { instrument in
                VStack(alignment: .leading, spacing: 2) {
                    Text(instrument.name)
                    Text(instrument.manufacturer)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .tag(instrument)
            }
        } detail: {
            if let audioUnit = viewModel.state.audioUnit {
                AudioUnitView(audioUnit: audioUnit)
            } else if viewModel.state.selectedComponent != nil {
                ProgressView("Loading Audio Unit...")
                    .frame(width: 480, height: 320)
            } else {
                Text("Select an instrument")
                    .foregroundStyle(.secondary)
                    .frame(width: 480, height: 320)
            }
        }
        .task {
            await viewModel.accept(action: .task)
        }
    }
}



// MARK: - View State

struct HostViewState {
    var components: [AudioUnitComponent]
    var selectedComponent: AudioUnitComponent?
    var audioUnit: LoadedAudioUnit?

    static var initial: Self {
        .init(components: [], selectedComponent: nil, audioUnit: nil)
    }
}
