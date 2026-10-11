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
}

@MainActor @Observable
final class HostPresenter {
    var content: HostContent {
        switch audioSettings.setup {
        case .checking:
            .loading
        case .unmet(let requirements):
            .unmet(requirements)
        case .met:
            session.slots.indices.contains(session.selectedIndex) ? session.slots[session.selectedIndex].hostContent : .empty
        }
    }

    var feedback: FeedbackToastViewState? {
        session.presetEvent.map { FeedbackToastViewState(id: $0.id, kind: $0.kind.feedbackKind) }
    }

    var presetLabel: String { "Preset: \(session.activePresetName ?? "—")" }

    var isSaveButtonDisabled: Bool { session.activePresetName == nil || !session.canSavePreset }
    var isRestoreButtonDisabled: Bool { session.activePresetName == nil || session.isBusy }
    var isStarFilled: Bool { purchases.state.isPro }

    private let session: SessionModelType
    private let audioSettings: AudioSettingsModelType
    private let purchases: PurchasesModelType

    init(
        session: SessionModelType,
        audioSettings: AudioSettingsModelType,
        purchases: PurchasesModelType
    ) {
        self.session = session
        self.audioSettings = audioSettings
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

private extension PluginSlotContent {
    var hostContent: HostContent {
        switch self {
        case .empty: .empty
        case .pending, .loading: .loading
        case .loaded(let audioUnit, _): .loaded(audioUnit)
        case .failed(_, let message): .failed(message)
        }
    }
}
