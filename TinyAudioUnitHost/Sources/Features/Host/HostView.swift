//
//  HostView.swift
//  TinyAudioUnitHost
//
//  Created by Alex Shubin on 19.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import PresetKit
import SwiftUI

struct HostView: View {
    @State var viewModel: HostViewModelType
    @Environment(\.openWindow) private var openWindow

    var body: some View {
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
        .task {
            await viewModel.accept(action: .task)
        }
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
            Spacer()
            Button {
                openWindow(id: "purchases")
            } label: {
                Image(systemName: "star.fill")
                    .foregroundStyle(.yellow)
            }
            .help("Pro features")
            SettingsLink {
                Image(systemName: "gear")
            }
        }
    }
}
