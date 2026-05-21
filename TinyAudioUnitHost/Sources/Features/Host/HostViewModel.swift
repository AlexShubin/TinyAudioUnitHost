//
//  HostViewModel.swift
//  TinyAudioUnitHost
//
//  Created by Alex Shubin on 19.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioUnitsKit
import Foundation
import Observation
import PresetKit

@MainActor
protocol HostViewModelType: AnyObject, Observable {
    var groups: [ManufacturerGroup] { get }
    var content: HostContent { get }
    var feedback: FeedbackToastViewState? { get }
    var presetLabel: String { get }
    var audioUnitTitle: String { get }
    var isAudioUnitPickerDisabled: Bool { get }
    var isSaveButtonDisabled: Bool { get }
    var isRestoreButtonDisabled: Bool { get }
    func accept(action: HostViewModelAction) async
}

enum HostViewModelAction {
    case task
    case selected(AudioUnitComponent)
    case saveCurrentPreset
    case restorePreset
    case feedbackToastAction(FeedbackToastAction)
}

struct ManufacturerGroup: Identifiable, Hashable {
    let manufacturer: String
    let components: [AudioUnitComponent]

    var id: String { manufacturer }
}

@MainActor @Observable
final class HostViewModel: HostViewModelType {
    private(set) var groups: [ManufacturerGroup] = []
    private(set) var feedback: FeedbackToastViewState?

    var content: HostContent { session.content }

    var presetLabel: String { "Preset: \(session.activeName ?? "—")" }

    var audioUnitTitle: String {
        if case .loaded(let loaded) = session.content {
            return loaded.component.name
        }
        return "Choose Audio Unit"
    }

    var isAudioUnitPickerDisabled: Bool { !session.content.isOperable }

    var isSaveButtonDisabled: Bool {
        session.activeName == nil || !session.content.isLoaded
    }

    var isRestoreButtonDisabled: Bool {
        session.activeName == nil || !session.content.isOperable
    }

    @ObservationIgnored private let library: AudioUnitComponentsLibraryType
    @ObservationIgnored private let session: SessionManagerType
    @ObservationIgnored private var sessionEventsListener: Task<Void, Never>?

    init(
        library: AudioUnitComponentsLibraryType,
        session: SessionManagerType
    ) {
        self.library = library
        self.session = session
        sessionEventsListener = Task { @MainActor [weak self, session] in
            for await event in session.makeEventStream() {
                guard let self else { return }
                switch event {
                case .saved:
                    self.feedback = FeedbackToastViewState(id: UUID(), kind: .saved)
                case .restored:
                    self.feedback = FeedbackToastViewState(id: UUID(), kind: .restored)
                case .requestNewPresetDialog, .requestProUpgrade:
                    break  // owned by Presets feature
                }
            }
        }
    }

    deinit {
        sessionEventsListener?.cancel()
    }

    func accept(action: HostViewModelAction) async {
        switch action {
        case .task:
            groups = grouped(library.components)
            await session.start()
        case .selected(let component):
            await session.loadComponent(component)
        case .saveCurrentPreset:
            session.saveCurrentPreset()
        case .restorePreset:
            await session.restoreActivePreset()
        case .feedbackToastAction(.timedOut):
            feedback = nil
        }
    }

    private func grouped(_ components: [AudioUnitComponent]) -> [ManufacturerGroup] {
        Dictionary(grouping: components, by: \.manufacturer)
            .map { ManufacturerGroup(manufacturer: $0.key, components: $0.value) }
            .sorted { $0.manufacturer.localizedCaseInsensitiveCompare($1.manufacturer) == .orderedAscending }
    }
}
