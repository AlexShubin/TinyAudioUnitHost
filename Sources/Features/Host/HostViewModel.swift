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
    case task
    case selected(audioUnitId: String)
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
    @ObservationIgnored private let library: AudioUnitComponentsLibraryType

    init(engine: AudioUnitHostEngineType, library: AudioUnitComponentsLibraryType) {
        self.engine = engine
        self.library = library
    }

    func accept(action: HostViewModelAction) async {
        switch action {
        case .task:
            state.instruments = library.components.map(AudioUnitViewState.init)
        case .selected(let id):
            state.selectedID = id
            state.audioUnit = nil
            state.audioUnit = await engine.load(componentId: id)
        }
    }
}

private extension AudioUnitViewState {
    init(from audioUnitComponent: AudioUnitComponent) {
        self.id = audioUnitComponent.id
        self.name = audioUnitComponent.name
        self.manufacturer = audioUnitComponent.manufacturer
    }
}
