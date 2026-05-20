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
    @Environment(\.openWindow) private var openWindow

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
        .sheet(isPresented: presetNameDialogPresented) {
            if let dialog = viewModel.presetNameDialog {
                PresetNameDialog(state: dialog, onAction: handlePresetNameDialogAction)
            }
        }
        .onChange(of: viewModel.openProWindowRequest) { _, newValue in
            if newValue != nil {
                openWindow(id: "purchases")
            }
        }
    }

    // MARK: - Sidebar (presets)

    @ViewBuilder
    private var sidebar: some View {
        if viewModel.presets.isEmpty {
            ContentUnavailableView(
                "No Presets Yet",
                systemImage: "rectangle.stack",
                description: Text("Use + in the toolbar to save the current sound as a preset.")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List(selection: presetSelectionBinding) {
                Section("Presets") {
                    ForEach(viewModel.presets, id: \.name) { preset in
                        Text(preset.name)
                            .tag(preset.name)
                            .contextMenu {
                                Button("Rename") {
                                    Task { await viewModel.accept(action: .presetRenameTapped(name: preset.name)) }
                                }
                                Button("Delete", role: .destructive) {
                                    Task { await viewModel.accept(action: .presetDeleteTapped(name: preset.name)) }
                                }
                            }
                    }
                }
            }
            .listStyle(.sidebar)
            .disabled(viewModel.content == .loading)
        }
    }

    private var presetSelectionBinding: Binding<String?> {
        Binding(
            get: { viewModel.activeName },
            set: { newSelection in
                if let newSelection {
                    Task { await viewModel.accept(action: .presetSelected(name: newSelection)) }
                }
            }
        )
    }

    // MARK: - Detail

    @ViewBuilder
    private var detail: some View {
        VStack(alignment: .leading, spacing: .zero) {
            audioUnitHeader
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            Divider()
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .overlay(alignment: .top) { feedbackOverlay }
        .animation(.snappy, value: viewModel.feedback != nil)
        .toolbar { toolbarContent }
    }

    @ViewBuilder
    private var content: some View {
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

    // MARK: - Audio Unit header (Logic-style dropdown)

    @ViewBuilder
    private var audioUnitHeader: some View {
        Menu {
            audioUnitMenuItems
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "puzzlepiece.extension")
                    .foregroundStyle(.secondary)
                Text(audioUnitHeaderTitle)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Image(systemName: "chevron.down")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .disabled(viewModel.content == .loading || !viewModel.isReady)
    }

    @ViewBuilder
    private var audioUnitMenuItems: some View {
        if viewModel.groups.isEmpty {
            Text("No Audio Units installed")
        } else {
            ForEach(viewModel.groups) { group in
                Menu(group.manufacturer) {
                    ForEach(group.components) { component in
                        Button(component.name) {
                            Task { await viewModel.accept(action: .selected(component)) }
                        }
                    }
                }
            }
        }
    }

    private var audioUnitHeaderTitle: String {
        if case .loaded(let loaded) = viewModel.content {
            return loaded.component.name
        }
        return "Choose Audio Unit"
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Text("Preset: \(viewModel.activeName ?? "—")")
                .padding([.leading], 12)
            Button {
                Task { await viewModel.accept(action: .restorePreset) }
            } label: {
                Image(systemName: "arrow.uturn.backward")
            }
            .help("Restore preset")
            .disabled(viewModel.activeName == nil || viewModel.content == .loading)
            Button {
                Task { await viewModel.accept(action: .saveCurrentPreset) }
            } label: {
                Image(systemName: "square.and.arrow.down")
            }
            .help("Save preset")
            .disabled(viewModel.activeName == nil || !viewModel.content.isLoaded)
            Button {
                Task { await viewModel.accept(action: .newPresetTapped) }
            } label: {
                Image(systemName: "plus")
            }
            .help("Save as new preset")
            .disabled(!viewModel.content.isLoaded)
            Spacer()
            Button {
                openWindow(id: "purchases")
            } label: {
                Image(systemName: viewModel.isPro ? "star.fill" : "star")
                    .foregroundStyle(viewModel.isPro ? .yellow : .secondary)
            }
            .help("Pro features")
            SettingsLink {
                Image(systemName: "gear")
            }
        }
    }

    // MARK: - Preset name dialog

    private var presetNameDialogPresented: Binding<Bool> {
        Binding(
            get: { viewModel.presetNameDialog != nil },
            set: { isPresented in
                if !isPresented {
                    Task { await viewModel.accept(action: .presetNameDialogAction(.cancel)) }
                }
            }
        )
    }

    private func handlePresetNameDialogAction(_ action: PresetNameDialogAction) {
        Task { await viewModel.accept(action: .presetNameDialogAction(action)) }
    }

    // MARK: - Focused values

    private var savePresetActions: SavePresetActions? {
        guard viewModel.activeName != nil else { return nil }
        return SavePresetActions(
            save: { Task { await viewModel.accept(action: .saveCurrentPreset) } },
            restore: { Task { await viewModel.accept(action: .restorePreset) } }
        )
    }
}
