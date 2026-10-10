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
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(alignment: .top) { feedbackOverlay }
            .animation(.snappy, value: presenter.feedback != nil)
            .toolbar { toolbarContent }
    }

    @ViewBuilder
    private var content: some View {
        switch presenter.content {
        case .unmet(let unmet):
            SetupChecklistView(unmet: unmet)
        case .empty:
            EmptySelectionView()
        case .idle, .loading:
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
