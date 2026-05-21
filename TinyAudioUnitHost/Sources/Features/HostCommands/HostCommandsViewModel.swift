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
    var isSaveButtonDisabled: Bool { get }
    var isRestoreButtonDisabled: Bool { get }
    var isSaveAsButtonDisabled: Bool { get }
    func accept(action: HostCommandsAction) async
}

enum HostCommandsAction: Sendable, Equatable {
    case save
    case restore
    case saveAs
}

@MainActor @Observable
final class HostCommandsViewModel: HostCommandsViewModelType {
    var isSaveButtonDisabled: Bool { session.activeName == nil || !session.content.isLoaded }
    var isRestoreButtonDisabled: Bool { session.activeName == nil || !session.content.isOperable }
    var isSaveAsButtonDisabled: Bool { !session.content.isLoaded }

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
        case .saveAs:
            await session.requestSaveAs()
        }
    }
}
