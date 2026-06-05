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
import PurchasesKit

@MainActor
protocol MainWindowViewModelType: AnyObject, Observable {
    func accept(action: MainWindowViewAction) async
}

enum MainWindowViewAction: Sendable, Equatable {
    case task
}

@MainActor @Observable
final class MainWindowViewModel: MainWindowViewModelType {
    @ObservationIgnored private let midiManager: MidiManagerType
    @ObservationIgnored private let engineReloader: EngineReloaderType
    @ObservationIgnored private let setupRefresher: SetupRefresherType
    @ObservationIgnored private let purchasesService: PurchasesServiceType

    init(
        midiManager: MidiManagerType,
        engineReloader: EngineReloaderType,
        setupRefresher: SetupRefresherType,
        purchasesService: PurchasesServiceType
    ) {
        self.midiManager = midiManager
        self.engineReloader = engineReloader
        self.setupRefresher = setupRefresher
        self.purchasesService = purchasesService
    }

    func accept(action: MainWindowViewAction) async {
        switch action {
        case .task:
            midiManager.startListening()
            engineReloader.startListening()
            setupRefresher.startListening()
            purchasesService.startListening()
        }
    }
}
