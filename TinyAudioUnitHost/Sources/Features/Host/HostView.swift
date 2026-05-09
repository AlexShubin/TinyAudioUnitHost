//
//  HostView.swift
//  TinyAudioUnitHost
//
//  Created by Alex Shubin on 19.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AppKit
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
            .disabled(viewModel.content == .loading || !viewModel.isReady)
            .navigationSplitViewColumnWidth(min: 220, ideal: 260)
        } detail: {
            Group {
                if viewModel.isReady {
                    switch viewModel.content {
                    case .empty:
                        VStack(spacing: 16) {
                            Image(nsImage: NSApp.applicationIconImage)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 96, height: 96)
                            Text("Select an audio unit")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundStyle(.secondary)
                        }
                        .frame(width: 480, height: 320)
                    case .loading:
                        VStack(spacing: 16) {
                            Image(nsImage: NSApp.applicationIconImage)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 96, height: 96)
                            ProgressView()
                                .foregroundStyle(.secondary)
                        }
                        .frame(width: 480, height: 320)
                    case .loaded(let audioUnit):
                        AudioUnitView(audioUnit: audioUnit)
                    }
                } else {
                    SetupChecklistView(unmet: viewModel.unmetRequirements)
                        .frame(width: 480, height: 320)
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Text(viewModel.presetTitle)
                        .padding([.leading], 12)
                    Image(systemName: "info.circle")
                        .foregroundStyle(.secondary)
                        .help("Only one preset is supported for now — multi-preset support is on the way.")
                    Button {
                        Task { await viewModel.accept(action: .restorePreset) }
                    } label: {
                        Image(systemName: "arrow.uturn.backward")
                    }
                    .help("Restore preset")
                    .disabled(!viewModel.isModified)
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
