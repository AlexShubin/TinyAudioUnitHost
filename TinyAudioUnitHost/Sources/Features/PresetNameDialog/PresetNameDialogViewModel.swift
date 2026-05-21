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

@MainActor
protocol PresetNameDialogViewModelType: AnyObject, Observable {
    var name: String { get }
    var error: PresetNameError? { get }
    var mode: PresetNameDialogMode { get }
    var isDismissed: Bool { get }
    func accept(action: PresetNameDialogAction) async
}

enum PresetNameDialogMode: Sendable, Equatable {
    case create
    case rename(currentName: String)
}

enum PresetNameDialogAction: Sendable, Equatable {
    case nameChanged(String)
    case cancel
    case commit
}

@MainActor @Observable
final class PresetNameDialogViewModel: PresetNameDialogViewModelType {
    let mode: PresetNameDialogMode
    private(set) var name: String
    private(set) var error: PresetNameError?
    private(set) var isDismissed: Bool = false

    @ObservationIgnored private let session: SessionManagerType
    @ObservationIgnored private let validator: PresetNameValidatorType

    init(
        mode: PresetNameDialogMode,
        initialName: String,
        session: SessionManagerType,
        validator: PresetNameValidatorType
    ) {
        self.mode = mode
        self.name = initialName
        self.session = session
        self.validator = validator
    }

    func accept(action: PresetNameDialogAction) async {
        switch action {
        case .nameChanged(let newName):
            error = validator.validate(name: newName, for: mode.validationMode)
            name = newName
        case .cancel:
            isDismissed = true
        case .commit:
            switch mode {
            case .create:
                switch session.saveAsNewPreset(name: name) {
                case .success:
                    isDismissed = true
                case .failure(let error):
                    self.error = error
                }
            case .rename(let currentName):
                switch session.renamePreset(from: currentName, to: name) {
                case .success:
                    isDismissed = true
                case .failure(let error):
                    self.error = error
                }
            }
        }
    }
}

private extension PresetNameDialogMode {
    var validationMode: ValidationMode {
        switch self {
        case .create: return .saveAs
        case .rename(let currentName): return .rename(currentName: currentName)
        }
    }
}
