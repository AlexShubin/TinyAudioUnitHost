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
                selection: Binding(
                    get: { viewModel.state.selectedComponent },
                    set: { component in
                        if let component {
                            Task { await viewModel.accept(action: .selected(component)) }
                        }
                    }
                )
            ) {
                ForEach(viewModel.state.groups) { group in
                    Section(
                        isExpanded: Binding(
                            get: { group.isExpanded },
                            set: { isExpanded in
                                Task {
                                    await viewModel.accept(
                                        action: .groupExpansionChanged(
                                            manufacturer: group.manufacturer,
                                            isExpanded: isExpanded
                                        )
                                    )
                                }
                            }
                        )
                    ) {
                        ForEach(group.components) { component in
                            Text(component.name).tag(component)
                        }
                    } header: {
                        Text(group.manufacturer)
                    }
                }
            }
            .listStyle(.sidebar)
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
    var groups: [ManufacturerGroup]
    var selectedComponent: AudioUnitComponent?
    var audioUnit: LoadedAudioUnit?

    static var initial: Self {
        .init(groups: [], selectedComponent: nil, audioUnit: nil)
    }
}

struct ManufacturerGroup: Identifiable, Hashable {
    let manufacturer: String
    let components: [AudioUnitComponent]
    var isExpanded: Bool

    var id: String { manufacturer }
}
