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
    var errorMessage: String? { get }
    var commitLabel: String { get }
    var canCommit: Bool { get }
    var isDismissed: Bool { get }
    func accept(action: PresetNameDialogAction) async
}

enum PresetNameDialogMode: Sendable, Equatable, Hashable, Identifiable {
    case saveAs
    case rename(currentName: String)

    var id: Self { self }
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

    var errorMessage: String? { error?.displayMessage }

    var commitLabel: String {
        switch mode {
        case .saveAs: return "Save"
        case .rename: return "Rename"
        }
    }

    var canCommit: Bool {
        error == nil && !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    @ObservationIgnored private let session: SessionManagerType
    @ObservationIgnored private let validator: PresetNameValidatorType

    init(
        mode: PresetNameDialogMode,
        session: SessionManagerType,
        validator: PresetNameValidatorType
    ) {
        self.mode = mode
        self.name = mode.defaultInitialName
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
            if let validationError = validator.validate(name: name, for: mode.validationMode) {
                error = validationError
                return
            }
            switch mode {
            case .saveAs:
                session.saveAsNewPreset(name: name)
            case .rename(let currentName):
                session.renamePreset(from: currentName, to: name)
            }
            isDismissed = true
        }
    }
}

private extension PresetNameDialogMode {
    var validationMode: ValidationMode {
        switch self {
        case .saveAs: return .saveAs
        case .rename(let currentName): return .rename(currentName: currentName)
        }
    }

    var defaultInitialName: String {
        switch self {
        case .saveAs: return ""
        case .rename(let currentName): return currentName
        }
    }
}

private extension PresetNameError {
    var displayMessage: String? {
        switch self {
        case .empty: return nil
        case .invalidCharacter: return "Name can't contain /, :, or start with a dot."
        case .duplicate: return "A preset with that name already exists."
        }
    }
}
