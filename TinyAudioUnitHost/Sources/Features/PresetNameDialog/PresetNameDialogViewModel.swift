//
//  PresetNameDialogViewModel.swift
//  TinyAudioUnitHost
//
//  Created by Alex Shubin on 20.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import Foundation
import Observation
import PresetKit

struct PresetNameDialogState: Sendable, Equatable {
    var name: String
    var error: PresetNameError?
    let mode: Mode

    enum Mode: Sendable, Equatable {
        case create
        case rename(currentName: String)
    }
}

enum PresetNameDialogAction: Sendable, Equatable {
    case nameChanged(String)
    case cancel
    case commit
}

enum PresetNameDialogOutcome: Sendable, Equatable {
    case cancelled
    case committed(mode: PresetNameDialogState.Mode)
}

@MainActor
protocol PresetNameDialogViewModelType: AnyObject, Observable {
    var state: PresetNameDialogState { get }
    var outcome: PresetNameDialogOutcome? { get }
    func accept(action: PresetNameDialogAction) async
}

@MainActor @Observable
final class PresetNameDialogViewModel: PresetNameDialogViewModelType {
    private(set) var state: PresetNameDialogState
    private(set) var outcome: PresetNameDialogOutcome?

    @ObservationIgnored private let session: SessionManagerType
    @ObservationIgnored private let validator: PresetNameValidatorType

    init(
        mode: PresetNameDialogState.Mode,
        initialName: String,
        session: SessionManagerType,
        validator: PresetNameValidatorType
    ) {
        self.state = PresetNameDialogState(name: initialName, error: nil, mode: mode)
        self.session = session
        self.validator = validator
    }

    func accept(action: PresetNameDialogAction) async {
        switch action {
        case .nameChanged(let name):
            let error = validator.validate(name: name, for: state.mode.validationMode)
            state = PresetNameDialogState(name: name, error: error, mode: state.mode)
        case .cancel:
            outcome = .cancelled
        case .commit:
            switch state.mode {
            case .create:
                switch session.saveAsNewPreset(name: state.name) {
                case .success:
                    outcome = .committed(mode: state.mode)
                case .failure(let error):
                    state = PresetNameDialogState(name: state.name, error: error, mode: state.mode)
                }
            case .rename(let currentName):
                switch session.renamePreset(from: currentName, to: state.name) {
                case .success:
                    outcome = .committed(mode: state.mode)
                case .failure(let error):
                    state = PresetNameDialogState(name: state.name, error: error, mode: state.mode)
                }
            }
        }
    }
}

private extension PresetNameDialogState.Mode {
    var validationMode: ValidationMode {
        switch self {
        case .create: return .saveAs
        case .rename(let currentName): return .rename(currentName: currentName)
        }
    }
}
