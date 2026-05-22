//
//  AppCommandsViewModel.swift
//  TinyAudioUnitHost
//
//  Created by Alex Shubin on 20.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import Foundation
import Observation

@MainActor
protocol AppCommandsViewModelType: AnyObject, Observable {
    var isSaveButtonDisabled: Bool { get }
    var isRestoreButtonDisabled: Bool { get }
    var isSaveAsButtonDisabled: Bool { get }
    func accept(action: AppCommandsAction) async
}

enum AppCommandsAction: Sendable, Equatable {
    case save
    case restore
    case saveAs
}

@MainActor @Observable
final class AppCommandsViewModel: AppCommandsViewModelType {
    var isSaveButtonDisabled: Bool { session.activeName == nil || !session.content.isLoaded }
    var isRestoreButtonDisabled: Bool { session.activeName == nil || !session.content.isOperable }
    var isSaveAsButtonDisabled: Bool { !session.content.isLoaded }

    @ObservationIgnored private let session: SessionManagerType
    @ObservationIgnored private let eventBus: SessionEventBusType

    init(
        session: SessionManagerType,
        eventBus: SessionEventBusType
    ) {
        self.session = session
        self.eventBus = eventBus
    }

    func accept(action: AppCommandsAction) async {
        switch action {
        case .save:
            session.saveCurrentPreset()
        case .restore:
            await session.restoreActivePreset()
        case .saveAs:
            eventBus.post(.saveAsRequested)
        }
    }
}
