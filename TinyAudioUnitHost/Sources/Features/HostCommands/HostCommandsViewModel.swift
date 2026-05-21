//
//  HostCommandsViewModel.swift
//  TinyAudioUnitHost
//
//  Created by Alex Shubin on 20.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import Foundation
import Observation

@MainActor
protocol HostCommandsViewModelType: AnyObject, Observable {
    var canSave: Bool { get }
    var canRestore: Bool { get }
    var canCreate: Bool { get }
    func accept(action: HostCommandsAction) async
}

enum HostCommandsAction: Sendable, Equatable {
    case save
    case restore
    case create
}

@MainActor @Observable
final class HostCommandsViewModel: HostCommandsViewModelType {
    var canSave: Bool { session.activeName != nil && session.content.isLoaded }
    var canRestore: Bool { session.activeName != nil && session.content.isOperable }
    var canCreate: Bool { session.content.isLoaded }

    @ObservationIgnored private let session: SessionManagerType

    init(session: SessionManagerType) {
        self.session = session
    }

    func accept(action: HostCommandsAction) async {
        switch action {
        case .save:
            session.saveCurrentPreset()
        case .restore:
            await session.restoreActivePreset()
        case .create:
            await session.requestNewPreset()
        }
    }
}
