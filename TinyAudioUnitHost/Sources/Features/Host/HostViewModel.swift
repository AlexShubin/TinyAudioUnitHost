//
//  HostViewModel.swift
//  TinyAudioUnitHost
//
//  Created by Alex Shubin on 19.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioSettingsKit
import AudioUnitsKit
import Foundation
import Observation
import PresetKit

enum HostViewModelAction {
    case task
    case selected(AudioUnitComponent)
    case saveCurrentPreset
    case restorePreset
    case feedbackToastAction(FeedbackToastAction)
}

@MainActor
protocol HostViewModelType: AnyObject, Observable {
    var groups: [ManufacturerGroup] { get }
    var selectedComponent: AudioUnitComponent? { get }
    var content: HostContent { get }
    var unmetRequirements: Set<SetupRequirement> { get }
    var feedback: FeedbackToastViewState? { get }
    var isReady: Bool { get }
    var activeName: String? { get }
    func accept(action: HostViewModelAction) async
}

@MainActor @Observable
final class HostViewModel: HostViewModelType {
    private(set) var groups: [ManufacturerGroup] = []
    private(set) var unmetRequirements: Set<SetupRequirement> = []
    private(set) var feedback: FeedbackToastViewState?

    var content: HostContent { session.content }
    var activeName: String? { session.activeName }
    var selectedComponent: AudioUnitComponent? { session.selectedComponent }
    var isReady: Bool { unmetRequirements.isEmpty }

    @ObservationIgnored private let library: AudioUnitComponentsLibraryType
    @ObservationIgnored private let session: SessionManagerType
    @ObservationIgnored private let setupChecker: SetupCheckerType
    @ObservationIgnored private var setupListener: Task<Void, Never>?
    @ObservationIgnored private var sessionEventsListener: Task<Void, Never>?

    init(
        library: AudioUnitComponentsLibraryType,
        session: SessionManagerType,
        setupChecker: SetupCheckerType
    ) {
        self.library = library
        self.session = session
        self.setupChecker = setupChecker
        setupListener = Task { [weak self, setupChecker] in
            for await unmet in setupChecker.unmetStream {
                self?.unmetRequirements = unmet
            }
        }
        sessionEventsListener = Task { @MainActor [weak self, session] in
            for await event in session.makeEventStream() {
                guard let self else { return }
                switch event {
                case .saved:
                    self.feedback = FeedbackToastViewState(id: UUID(), kind: .saved)
                case .restored:
                    self.feedback = FeedbackToastViewState(id: UUID(), kind: .restored)
                case .requestNewPresetDialog, .requestProUpgrade:
                    break  // owned by PresetsSidebar feature
                }
            }
        }
    }

    deinit {
        setupListener?.cancel()
        sessionEventsListener?.cancel()
    }

    func accept(action: HostViewModelAction) async {
        switch action {
        case .task:
            groups = grouped(library.components)
            await setupChecker.refresh()
            await session.start()
        case .selected(let component):
            guard isReady else { return }
            await session.loadComponent(component)
        case .saveCurrentPreset:
            _ = session.saveCurrentPreset()
        case .restorePreset:
            _ = await session.restoreActivePreset()
        case .feedbackToastAction(.timedOut):
            feedback = nil
        }
    }

    private func grouped(_ components: [AudioUnitComponent]) -> [ManufacturerGroup] {
        Dictionary(grouping: components, by: \.manufacturer)
            .map { ManufacturerGroup(manufacturer: $0.key, components: $0.value, isExpanded: false) }
            .sorted { $0.manufacturer.localizedCaseInsensitiveCompare($1.manufacturer) == .orderedAscending }
    }
}

struct ManufacturerGroup: Identifiable, Hashable {
    let manufacturer: String
    let components: [AudioUnitComponent]
    var isExpanded: Bool

    var id: String { manufacturer }
}
