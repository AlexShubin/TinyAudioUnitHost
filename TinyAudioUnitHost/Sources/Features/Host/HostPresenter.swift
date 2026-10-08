//
//  HostPresenter.swift
//  TinyAudioUnitHost
//
//  Created by Alex Shubin on 19.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioUnitsKit
import PurchasesKit

@MainActor
protocol HostPresenterType {
    var groups: [ManufacturerGroup] { get }
    var content: HostContent { get }
    var feedback: FeedbackToastViewState? { get }
    var presetLabel: String { get }
    var audioUnitTitle: String { get }
    var isAudioUnitPickerDisabled: Bool { get }
    var isSaveButtonDisabled: Bool { get }
    var isRestoreButtonDisabled: Bool { get }
    var isStarFilled: Bool { get }
    func task() async
    func select(_ component: AudioUnitComponent) async
    func savePreset()
    func restorePreset() async
    func feedbackTimedOut()
}

struct ManufacturerGroup: Identifiable, Hashable {
    let manufacturer: String
    let components: [AudioUnitComponent]

    var id: String { manufacturer }
}

@MainActor
struct HostPresenter: HostPresenterType {
    var groups: [ManufacturerGroup] {
        Dictionary(grouping: library.components, by: \.manufacturer)
            .map { ManufacturerGroup(manufacturer: $0.key, components: $0.value) }
            .sorted { $0.manufacturer.localizedCaseInsensitiveCompare($1.manufacturer) == .orderedAscending }
    }

    var content: HostContent { session.content }

    var feedback: FeedbackToastViewState? {
        session.presetEvent.map { FeedbackToastViewState(id: $0.id, kind: $0.kind.feedbackKind) }
    }

    var presetLabel: String { "Preset: \(session.activeName ?? "—")" }

    var audioUnitTitle: String {
        if case .loaded(let loaded) = session.content {
            return loaded.component.name
        }
        return "Choose Audio Unit"
    }

    var isAudioUnitPickerDisabled: Bool { !session.content.isOperable }
    var isSaveButtonDisabled: Bool { session.activeName == nil || !session.content.isLoaded }
    var isRestoreButtonDisabled: Bool { session.activeName == nil || !session.content.isOperable }
    var isStarFilled: Bool { purchases.state.isPro }

    private let library: AudioUnitComponentsLibraryType
    private let session: SessionModelType
    private let purchases: PurchasesModelType

    init(
        library: AudioUnitComponentsLibraryType,
        session: SessionModelType,
        purchases: PurchasesModelType
    ) {
        self.library = library
        self.session = session
        self.purchases = purchases
    }

    func task() async {
        await session.start()
    }

    func select(_ component: AudioUnitComponent) async {
        await session.loadComponent(component)
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
