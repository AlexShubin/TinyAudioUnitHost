//
//  HostPresenter.swift
//  TinyAudioUnitHost
//
//  Created by Alex Shubin on 19.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioSettingsKit
import AudioUnitsKit
import ChannelStripKit
import Observation
import PresetKit
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
            channelStrip.slots.indices.contains(channelStrip.selectedIndex) ? channelStrip.slots[channelStrip.selectedIndex].hostContent : .empty
        }
    }

    var feedback: FeedbackToastViewState? {
        presets.event.map { FeedbackToastViewState(id: $0.id, kind: $0.kind.feedbackKind) }
    }

    var presetLabel: String { "Preset: \(presets.activeName ?? "—")" }

    var isSaveButtonDisabled: Bool { presets.activeName == nil || !channelStrip.isSavable }
    var isRestoreButtonDisabled: Bool { presets.activeName == nil || channelStrip.isBusy }
    var isStarFilled: Bool { purchases.state.isPro }

    private let channelStrip: ChannelStripModelType
    private let presets: PresetsModelType
    private let audioSettings: AudioSettingsModelType
    private let purchases: PurchasesModelType

    init(
        channelStrip: ChannelStripModelType,
        presets: PresetsModelType,
        audioSettings: AudioSettingsModelType,
        purchases: PurchasesModelType
    ) {
        self.channelStrip = channelStrip
        self.presets = presets
        self.audioSettings = audioSettings
        self.purchases = purchases
    }

    func savePreset() {
        guard let preset = channelStrip.preset else { return }
        presets.saveCurrent(preset: preset)
    }

    func restorePreset() async {
        await presets.restoreActive()
    }

    func feedbackTimedOut() {
        presets.acknowledgeEvent()
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
        case .loading: .loading
        case .loaded(let audioUnit, _): .loaded(audioUnit)
        case .failed(_, _, _, let message): .failed(message)
        }
    }
}
