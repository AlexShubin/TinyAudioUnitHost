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
        VStack(alignment: .leading) {
            Picker(
                "Instrument",
                selection: Binding(
                    get: { viewModel.state.selectedID },
                    set: { id in
                        if let id {
                            Task { await viewModel.accept(action: .selected(audioUnitId: id)) }
                        }
                    }
                )
            ) {
                ForEach(viewModel.state.audioUnits) { instrument in
                    Text(instrument.name).tag(instrument.id)
                }
            }
            .pickerStyle(.automatic)
            .padding(16)

            Group {
                if let audioUnit = viewModel.state.audioUnit {
                    AudioUnitView(audioUnit: audioUnit)
                } else if viewModel.state.selectedID != nil {
                    ProgressView("Loading Audio Unit...")
                        .frame(width: 480, height: 320)
                } else {
                    Text("Select an instrument")
                        .foregroundStyle(.secondary)
                        .frame(width: 480, height: 320)
                }
            }
            .background(Color.gray.opacity(0.1))
        }
        .task {
            await viewModel.accept(action: .task)
        }
    }
}



// MARK: - View State

struct HostViewState {
    var audioUnits: [AudioUnitViewState]
    var selectedID: String?
    var audioUnit: AUAudioUnit?
}

struct AudioUnitViewState: Identifiable, Equatable {
    let id: String
    let name: String
}

// MARK: - Preview

@MainActor @Observable
private class PreviewHostViewModel: HostViewModelType {
    var state = HostViewState(audioUnits: [], selectedID: nil, audioUnit: nil)
    func accept(action: HostViewModelAction) async {}
}

#Preview {
    HostView(viewModel: PreviewHostViewModel())
}
