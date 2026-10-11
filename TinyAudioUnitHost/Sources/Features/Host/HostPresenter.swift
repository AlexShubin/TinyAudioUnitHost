//
//  HostPresenter.swift
//  TinyAudioUnitHost
//
//  Created by Alex Shubin on 19.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioSettingsKit
import AudioUnitsKit
import Observation
import PurchasesKit

enum HostContent: Sendable, Equatable {
    case unmet(Set<SetupRequirement>)
    case empty
    case loading
    case loaded(LoadedAudioUnit)
    case failed(String)

    var isLoaded: Bool {
        if case .loaded = self { return true }
        return false
    }

    /// True for states the user can act on from the UI. False while loading and when blocked (.unmet).
    var isOperable: Bool {
        switch self {
        case .empty, .loaded, .failed: return true
        case .loading, .unmet: return false
        }
    }
}

@MainActor @Observable
final class HostPresenter {
    var content: HostContent { session.content }

    var feedback: FeedbackToastViewState? {
        session.presetEvent.map { FeedbackToastViewState(id: $0.id, kind: $0.kind.feedbackKind) }
    }

    var presetLabel: String { "Preset: \(session.activePresetName ?? "—")" }

    var isSaveButtonDisabled: Bool { session.activePresetName == nil || !session.content.isLoaded }
    var isRestoreButtonDisabled: Bool { session.activePresetName == nil || !session.content.isOperable }
    var isStarFilled: Bool { purchases.state.isPro }

    private let session: SessionModelType
    private let purchases: PurchasesModelType

    init(
        session: SessionModelType,
        purchases: PurchasesModelType
    ) {
        self.session = session
        self.purchases = purchases
    }

    func savePreset() {
        session.saveCurrentPreset()
    }

    func restorePreset() async {
        await session.restoreActivePreset()
    }

    func feedbackTimedOut() {
        session.acknowledgePresetEvent()
    }
}

private extension PresetEvent.Kind {
    var feedbackKind: FeedbackToastViewState.Kind {
        switch self {
        case .saved: .saved
        case .restored: .restored
        }
    }
}
