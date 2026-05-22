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
import PurchasesKit

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
    var isStarFilled: Bool { get }
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
    private(set) var isStarFilled: Bool = false

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
    @ObservationIgnored private let purchasesService: PurchasesServiceType
    @ObservationIgnored private let eventBus: SessionEventBusType
    @ObservationIgnored private var isProListener: Task<Void, Never>?
    @ObservationIgnored private var sessionEventsListener: Task<Void, Never>?

    init(
        library: AudioUnitComponentsLibraryType,
        session: SessionManagerType,
        purchasesService: PurchasesServiceType,
        eventBus: SessionEventBusType
    ) {
        self.library = library
        self.session = session
        self.purchasesService = purchasesService
        self.eventBus = eventBus
        isProListener = Task { @MainActor [weak self, purchasesService] in
            for await value in await purchasesService.makeIsProStream() {
                self?.isStarFilled = value
            }
        }
        let stream = eventBus.makeEventStream()
        sessionEventsListener = Task { @MainActor [weak self] in
            for await event in stream {
                guard let self else { return }
                switch event {
                case .saved:
                    self.feedback = FeedbackToastViewState(id: UUID(), kind: .saved)
                case .restored:
                    self.feedback = FeedbackToastViewState(id: UUID(), kind: .restored)
                case .saveAsRequested:
                    break  // owned by Presets feature
                }
            }
        }
    }

    deinit {
        isProListener?.cancel()
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
