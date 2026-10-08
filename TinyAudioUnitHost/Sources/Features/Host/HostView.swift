//
//  HostView.swift
//  TinyAudioUnitHost
//
//  Created by Alex Shubin on 19.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import SwiftUI

struct HostView: View {
    @State var presenter: HostPresenter
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
        .animation(.snappy, value: presenter.feedback != nil)
        .toolbar { toolbarContent }
        .task {
            await presenter.task()
        }
    }

    @ViewBuilder
    private var content: some View {
        switch presenter.content {
        case .unmet(let unmet):
            SetupChecklistView(unmet: unmet)
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
    }

    @ViewBuilder
    private var feedbackOverlay: some View {
        if let feedback = presenter.feedback {
            FeedbackToast(state: feedback) {
                presenter.feedbackTimedOut()
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
                Text(presenter.audioUnitTitle)
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
        .disabled(presenter.isAudioUnitPickerDisabled)
    }

    @ViewBuilder
    private var audioUnitMenuItems: some View {
        if presenter.groups.isEmpty {
            Text("No Audio Units installed")
        } else {
            ForEach(presenter.groups) { group in
                Menu(group.manufacturer) {
                    ForEach(group.components) { component in
                        Button(component.name) {
                            Task { await presenter.select(component) }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Text(presenter.presetLabel)
                .padding([.leading], 12)
            Button {
                Task { await presenter.restorePreset() }
            } label: {
                Image(systemName: "arrow.uturn.backward")
            }
            .help("Restore preset")
            .disabled(presenter.isRestoreButtonDisabled)
            Button {
                presenter.savePreset()
            } label: {
                Image(systemName: "square.and.arrow.down")
            }
            .help("Save preset")
            .disabled(presenter.isSaveButtonDisabled)
            Spacer()
            Button {
                openWindow(id: "purchases")
            } label: {
                Image(systemName: presenter.isStarFilled ? "star.fill" : "star")
                    .foregroundStyle(presenter.isStarFilled ? .yellow : .secondary)
            }
            .help("Pro features")
            SettingsLink {
                Image(systemName: "gear")
            }
        }
    }
}
