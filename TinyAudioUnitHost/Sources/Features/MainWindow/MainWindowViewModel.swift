//
//  MainWindowViewModel.swift
//  TinyAudioUnitHost
//
//  Created by Alex Shubin on 22.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioSettingsKit
import EngineKit
import Observation

@MainActor
protocol MainWindowViewModelType: AnyObject, Observable {
    func accept(action: MainWindowViewAction) async
}

enum MainWindowViewAction: Sendable, Equatable {
    case task
}

@MainActor @Observable
final class MainWindowViewModel: MainWindowViewModelType {
    @ObservationIgnored private let engineReloader: EngineReloaderType
    @ObservationIgnored private let setupRefresher: SetupRefresherType

    init(
        engineReloader: EngineReloaderType,
        setupRefresher: SetupRefresherType
    ) {
        self.engineReloader = engineReloader
        self.setupRefresher = setupRefresher
    }

    func accept(action: MainWindowViewAction) async {
        switch action {
        case .task:
            engineReloader.startListening()
            setupRefresher.startListening()
        }
    }
}
