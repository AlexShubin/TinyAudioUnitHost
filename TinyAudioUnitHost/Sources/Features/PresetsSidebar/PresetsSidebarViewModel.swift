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
}

@MainActor
protocol PresetsSidebarViewModelType: AnyObject, Observable {
    var presets: [Preset] { get }
    var activeName: String? { get }
    var isInteractionDisabled: Bool { get }
    var renameTarget: String? { get }
    func accept(action: PresetsSidebarAction) async
}

@MainActor @Observable
final class PresetsSidebarViewModel: PresetsSidebarViewModelType {
    private(set) var renameTarget: String?

    var presets: [Preset] { session.presets }
    var activeName: String? { session.activeName }
    var isInteractionDisabled: Bool { session.content == .loading }

    @ObservationIgnored private let session: SessionManagerType

    init(session: SessionManagerType) {
        self.session = session
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
        }
    }
}
