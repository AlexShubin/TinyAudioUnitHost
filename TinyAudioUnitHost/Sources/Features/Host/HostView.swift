//
//  HostView.swift
//  TinyAudioUnitHost
//
//  Created by Alex Shubin on 19.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import PresetKit
import SwiftUI

private enum SidebarTab: Hashable {
    case audioUnits
    case presets
}

struct HostView: View {
    @State var viewModel: HostViewModelType
    @State private var sidebarTab: SidebarTab = .audioUnits

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 220, ideal: 260)
        } detail: {
            detail
        }
        .task {
            await viewModel.accept(action: .task)
        }
        .focusedSceneValue(\.savePresetActions, savePresetActions)
    }

    // MARK: - Sidebar

    @ViewBuilder
    private var sidebar: some View {
        VStack {
            Picker("", selection: $sidebarTab) {
                Text("Audio Units").tag(SidebarTab.audioUnits)
                Text("Presets").tag(SidebarTab.presets)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 10)
            .padding(.top, 10)
            .padding(.bottom, 6)

            switch sidebarTab {
            case .audioUnits:
                audioUnitsSidebar
            case .presets:
                presetsSidebar
            }
        }
    }

    @ViewBuilder
    private var audioUnitsSidebar: some View {
        if viewModel.groups.isEmpty {
            ContentUnavailableView(
                "No Audio Units",
                systemImage: "puzzlepiece.extension",
                description: Text("Install audio unit plug-ins to host them here.")
            )
        } else {
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
        }
    }

    @ViewBuilder
    private var presetsSidebar: some View {
        PresetsSidebar(
            state: PresetsSidebarViewState(
                presets: viewModel.presets,
                activeName: viewModel.activeName,
                canAdd: viewModel.content.isLoaded
            ),
            onAction: handlePresetsSidebarAction
        )
    }

    private func handlePresetsSidebarAction(_ action: PresetsSidebarAction) {
        Task { await viewModel.accept(action: .presetsSidebarAction(action)) }
    }

    // MARK: - Detail

    @ViewBuilder
    private var detail: some View {
        Group {
            if viewModel.isReady {
                switch viewModel.content {
                case .empty:
                    EmptySelectionView()
                case .loading:
                    LoadingView()
                case .loaded(let audioUnit):
                    AudioUnitView(audioUnit: audioUnit)
                case .failed(let message):
                    PlaceholderView {
                        Text(message)
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
            } else {
                SetupChecklistView(unmet: viewModel.unmetRequirements)
            }
        }
        .overlay(alignment: .top) { feedbackOverlay }
        .animation(.snappy, value: viewModel.feedback != nil)
        .toolbar { toolbarContent }
    }

    @ViewBuilder
    private var feedbackOverlay: some View {
        if let feedback = viewModel.feedback {
            FeedbackToast(state: feedback) { action in
                Task { await viewModel.accept(action: .feedbackToastAction(action)) }
            }
            .padding(.top, 12)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Text("Preset: Default")
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
            .disabled(!viewModel.content.isLoaded)
            Button {
                Task { await viewModel.accept(action: .saveCurrentPreset) }
            } label: {
                Image(systemName: "square.and.arrow.down")
            }
            .help("Save preset")
            .disabled(!viewModel.content.isLoaded)
            Spacer()
            SettingsLink {
                Image(systemName: "gear")
            }
        }
    }

    // MARK: - Focused values

    private var savePresetActions: SavePresetActions? {
        guard viewModel.content.isLoaded else { return nil }
        return SavePresetActions(
            save: { Task { await viewModel.accept(action: .saveCurrentPreset) } },
            restore: { Task { await viewModel.accept(action: .restorePreset) } }
        )
    }
}
