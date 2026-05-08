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
                    get: { viewModel.selectedComponent },
                    set: { component in
                        if let component {
                            Task { await viewModel.accept(action: .selected(component)) }
                        }
                    }
                )
            ) {
                ForEach(viewModel.groups) { group in
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
            .disabled(viewModel.content == .loading)
            .navigationSplitViewColumnWidth(min: 220, ideal: 260)
        } detail: {
            Group {
                switch viewModel.content {
                case .empty:
                    Text("Select an audio unit")
                        .foregroundStyle(.secondary)
                        .frame(width: 480, height: 320)
                case .loading:
                    ProgressView("Loading Audio Unit...")
                        .frame(width: 480, height: 320)
                case .loaded(let audioUnit):
                    AudioUnitView(audioUnit: audioUnit)
                }
            }
            .navigationTitle(viewModel.presetTitle)
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button {
                        Task { await viewModel.accept(action: .saveCurrentPreset) }
                    } label: {
                        Image(systemName: "square.and.arrow.down")
                    }
                    .help("Save preset")
                    Spacer()
                    SettingsLink {
                        Image(systemName: "gear")
                    }
                }
            }
        }
        .task {
            await viewModel.accept(action: .task)
        }
    }
}
