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
    @State private var audioUnitSize = CGSize(width: 480, height: 320)

    var body: some View {
        VStack {
            HStack {
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
                    ForEach(viewModel.state.instruments) { instrument in
                        Text(instrument.name).tag(Optional(instrument.id))
                    }
                }
                .pickerStyle(.automatic)
                Spacer()
            }
            .padding(16)
            .frame(width: audioUnitSize.width)

            Rectangle()
                .fill(Color.gray.opacity(0.1))
                .overlay {
                    if let audioUnit = viewModel.state.audioUnit {
                        AudioUnitView(audioUnit: audioUnit) { size in
                            audioUnitSize = size
                        }
                    } else if viewModel.state.selectedID != nil {
                        ProgressView("Loading Audio Unit...")
                    } else {

                        Text("Select an instrument")
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: audioUnitSize.width, height: audioUnitSize.height)
        }
        .task {
            await viewModel.accept(action: .task)
        }
    }
}

struct AudioUnitViewState: Identifiable, Equatable {
    let id: String
    let name: String
    let manufacturer: String
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
