//
//  PresetNameDialogPresenter.swift
//  TinyAudioUnitHost
//
//  Created by Alex Shubin on 20.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import Foundation
import PresetKit

@MainActor
protocol PresetNameDialogPresenterType {
    var initialName: String { get }
    var commitLabel: String { get }
    func errorMessage(for name: String) -> String?
    func canCommit(name: String) -> Bool
    func commit(name: String)
    func cancel()
}

enum PresetNameDialogMode: Sendable, Equatable, Hashable, Identifiable {
    case saveAs
    case rename(currentName: String)

    var id: Self { self }
}

@MainActor
struct PresetNameDialogPresenter: PresetNameDialogPresenterType {
    var initialName: String {
        switch mode {
        case .saveAs: return ""
        case .rename(let currentName): return currentName
        }
    }

    var commitLabel: String {
        switch mode {
        case .saveAs: return "Save"
        case .rename: return "Rename"
        }
    }

    private let mode: PresetNameDialogMode
    private let session: SessionModelType
    private let validator: PresetNameValidatorType
    private let navigation: NavigationModelType

    init(
        mode: PresetNameDialogMode,
        session: SessionModelType,
        validator: PresetNameValidatorType,
        navigation: NavigationModelType
    ) {
        self.mode = mode
        self.session = session
        self.validator = validator
        self.navigation = navigation
    }

    func errorMessage(for name: String) -> String? {
        validate(name)?.displayMessage
    }

    func canCommit(name: String) -> Bool {
        validate(name) == nil
    }

    func commit(name: String) {
        guard validate(name) == nil else { return }
        switch mode {
        case .saveAs:
            session.saveAsNewPreset(name: name)
        case .rename(let currentName):
            session.renamePreset(from: currentName, to: name)
        }
        navigation.presetsDestination = nil
    }

    func cancel() {
        navigation.presetsDestination = nil
    }

    private func validate(_ name: String) -> PresetNameError? {
        validator.validate(name: name, for: mode.validationMode)
    }
}

private extension PresetNameDialogMode {
    var validationMode: ValidationMode {
        switch self {
        case .saveAs: return .saveAs
        case .rename(let currentName): return .rename(currentName: currentName)
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
