//
//  HostView.swift
//  TinyAudioUnitHost
//
//  Created by Alex Shubin on 19.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioToolbox
import SwiftUI

struct HostView: View {
    @State var viewModel: HostViewModelType

    var body: some View {
        NavigationSplitView {
            InstrumentListView(
                instruments: viewModel.state.instruments,
                selectedID: Binding(
                    get: { viewModel.state.selectedID },
                    set: { id in
                        if let id {
                            Task { await viewModel.accept(action: .selected(audioUnitId: id)) }
                        }
                    }
                )
            )
            .navigationSplitViewColumnWidth(min: 200, ideal: 280, max: 400)
        } detail: {
            if let audioUnit = viewModel.state.audioUnit {
                AudioUnitView(audioUnit: audioUnit)
            } else if viewModel.state.selectedID != nil {
                ProgressView("Loading Audio Unit...")
            } else {
                Text("Select an instrument")
                    .foregroundStyle(.secondary)
            }
        }
        .task {
            await viewModel.accept(action: .task)
        }
    }
}

// MARK: - View State

struct HostViewState {
    var instruments: [AudioUnitViewState]
    var selectedID: String?
    var audioUnit: AUAudioUnit?
}

// MARK: - Preview

@MainActor @Observable
private class PreviewHostViewModel: HostViewModelType {
    var state = HostViewState(instruments: [], selectedID: nil, audioUnit: nil)
    func accept(action: HostViewModelAction) async {}
}

#Preview {
    HostView(viewModel: PreviewHostViewModel())
}
