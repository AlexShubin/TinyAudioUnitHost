//
//  HostCommandsViewModel.swift
//  TinyAudioUnitHost
//
//  Created by Alex Shubin on 20.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import Foundation
import Observation

enum HostCommandsAction: Sendable, Equatable {
    case save
    case restore
}

@MainActor
protocol HostCommandsViewModelType: AnyObject, Observable {
    var canSave: Bool { get }
    var canRestore: Bool { get }
    func accept(action: HostCommandsAction) async
}

@MainActor @Observable
final class HostCommandsViewModel: HostCommandsViewModelType {
    var canSave: Bool { session.activeName != nil && session.content.isLoaded }
    var canRestore: Bool { session.activeName != nil && session.content != .loading }

    @ObservationIgnored private let session: SessionManagerType

    init(session: SessionManagerType) {
        self.session = session
    }

    func accept(action: HostCommandsAction) async {
        switch action {
        case .save:
            _ = session.saveCurrentPreset()
        case .restore:
            _ = await session.restoreActivePreset()
        }
    }
}
