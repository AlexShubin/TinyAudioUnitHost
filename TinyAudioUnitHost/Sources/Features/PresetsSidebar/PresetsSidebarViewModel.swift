//
//  PresetsSidebarViewModel.swift
//  TinyAudioUnitHost
//
//  Created by Alex Shubin on 20.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import Foundation
import Observation
import PresetKit

enum PresetsSidebarAction: Sendable, Equatable {
    case selected(name: String)
    case renameTapped(name: String)
    case deleteTapped(name: String)
    case dismissRenameDialog
    case createTapped
    case dismissCreateDialog
}

@MainActor
protocol PresetsSidebarViewModelType: AnyObject, Observable {
    var presets: [Preset] { get }
    var activeName: String? { get }
    var isInteractionDisabled: Bool { get }
    var canCreate: Bool { get }
    var renameTarget: String? { get }
    var isCreateDialogPresented: Bool { get }
    var openProWindowRequest: UUID? { get }
    func accept(action: PresetsSidebarAction) async
}

@MainActor @Observable
final class PresetsSidebarViewModel: PresetsSidebarViewModelType {
    private(set) var renameTarget: String?
    private(set) var isCreateDialogPresented: Bool = false
    private(set) var openProWindowRequest: UUID?

    var presets: [Preset] { session.presets }
    var activeName: String? { session.activeName }
    var isInteractionDisabled: Bool { session.content == .loading }
    var canCreate: Bool { session.content.isLoaded }

    @ObservationIgnored private let session: SessionManagerType
    @ObservationIgnored private var sessionEventsListener: Task<Void, Never>?

    init(session: SessionManagerType) {
        self.session = session
        sessionEventsListener = Task { @MainActor [weak self, session] in
            for await event in session.makeEventStream() {
                guard let self else { return }
                switch event {
                case .requestNewPresetDialog:
                    self.isCreateDialogPresented = true
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

    func accept(action: PresetsSidebarAction) async {
        switch action {
        case .selected(let name):
            await session.selectPreset(name: name)
        case .renameTapped(let name):
            renameTarget = name
        case .deleteTapped(let name):
            session.deletePreset(name: name)
        case .dismissRenameDialog:
            renameTarget = nil
        case .createTapped:
            await session.requestNewPreset()
        case .dismissCreateDialog:
            isCreateDialogPresented = false
        }
    }
}
