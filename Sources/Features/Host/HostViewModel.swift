//
//  HostViewModel.swift
//  TinyAudioUnitHost
//
//  Created by Alex Shubin on 19.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioToolbox
import Observation

enum HostViewModelAction {
    case appeared
    case selected(AudioUnitComponent)
}

@MainActor
protocol HostViewModelType: Observable {
    var state: HostViewState { get }
    func accept(action: HostViewModelAction) async
}

@MainActor @Observable
final class HostViewModel: HostViewModelType {
    private(set) var state = HostViewState(instruments: [], selectedID: nil, audioUnit: nil)

    @ObservationIgnored private let engine: AudioUnitHostEngineType

    init(engine: AudioUnitHostEngineType) {
        self.engine = engine
    }

    func accept(action: HostViewModelAction) async {
        switch action {
        case .appeared:
            await engine.loadInstruments()
            state.instruments = engine.availableInstruments
        case .selected(let component):
            state.selectedID = component.id
            state.audioUnit = nil
            state.audioUnit = await engine.select(component)
        }
    }
}
