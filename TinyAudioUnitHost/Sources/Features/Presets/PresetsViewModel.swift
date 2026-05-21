//
//  PresetsViewModel.swift
//  TinyAudioUnitHost
//
//  Created by Alex Shubin on 20.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import Foundation
import Observation
import PresetKit

@MainActor
protocol PresetsViewModelType: AnyObject, Observable {
    var presets: [Preset] { get }
    var activeName: String? { get }
    var isInteractionDisabled: Bool { get }
    var isSaveAsButtonDisabled: Bool { get }
    var presentedPresetNameDialog: PresetNameDialogMode? { get }
    var openProWindowRequest: UUID? { get }
    func accept(action: PresetsAction) async
}

enum PresetsAction: Sendable, Equatable {
    case selected(name: String)
    case renameTapped(name: String)
    case deleteTapped(name: String)
    case saveAsTapped
    case dismissDialog
}

@MainActor @Observable
final class PresetsViewModel: PresetsViewModelType {
    private(set) var presentedPresetNameDialog: PresetNameDialogMode?
    private(set) var openProWindowRequest: UUID?

    var presets: [Preset] { session.presets }
    var activeName: String? { session.activeName }
    var isInteractionDisabled: Bool { !session.content.isOperable }
    var isSaveAsButtonDisabled: Bool { !session.content.isLoaded }

    @ObservationIgnored private let session: SessionManagerType
    @ObservationIgnored private var sessionEventsListener: Task<Void, Never>?

    init(session: SessionManagerType) {
        self.session = session
        // makeEventStream is called synchronously here so the continuation is
        // registered before init returns. Tests that emit immediately after
        // construction would otherwise lose the event.
        let stream = session.makeEventStream()
        sessionEventsListener = Task { @MainActor [weak self] in
            for await event in stream {
                guard let self else { return }
                switch event {
                case .requestSaveAsDialog:
                    self.presentedPresetNameDialog = .saveAs
                case .requestProUpgrade:
                    self.openProWindowRequest = UUID()
                case .saved, .restored:
                    break  // owned by Host feature
                }
            }
        }
    }

    deinit {
        sessionEventsListener?.cancel()
    }

    func accept(action: PresetsAction) async {
        switch action {
        case .selected(let name):
            await session.selectPreset(name: name)
        case .renameTapped(let name):
            presentedPresetNameDialog = .rename(currentName: name)
        case .deleteTapped(let name):
            session.deletePreset(name: name)
        case .saveAsTapped:
            await session.requestSaveAs()
        case .dismissDialog:
            presentedPresetNameDialog = nil
        }
    }
}
