//
//  HostPresenter.swift
//  TinyAudioUnitHost
//
//  Created by Alex Shubin on 19.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import Observation
import PurchasesKit

@MainActor @Observable
final class HostPresenter {
    var content: HostContent { session.content }

    var feedback: FeedbackToastViewState? {
        session.presetEvent.map { FeedbackToastViewState(id: $0.id, kind: $0.kind.feedbackKind) }
    }

    var presetLabel: String { "Preset: \(session.activeName ?? "—")" }

    var isSaveButtonDisabled: Bool { session.activeName == nil || !session.content.isLoaded }
    var isRestoreButtonDisabled: Bool { session.activeName == nil || !session.content.isOperable }
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
