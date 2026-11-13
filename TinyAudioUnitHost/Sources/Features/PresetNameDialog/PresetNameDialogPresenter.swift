//
//  PresetNameDialogPresenter.swift
//  TinyAudioUnitHost
//
//  Created by Alex Shubin on 20.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import ChannelStripKit
import Observation
import PresetKit

@MainActor @Observable
final class PresetNameDialogPresenter {
    var name: String
    private(set) var isDismissed = false

    var commitLabel: String {
        switch mode {
        case .saveAs: return "Save"
        case .rename: return "Rename"
        }
    }

    var errorMessage: String? { validationError?.displayMessage }
    var canCommit: Bool { validationError == nil }

    private let mode: PresetNameDialogMode
    private let channelStrip: ChannelStripModelType
    private let presets: PresetsModelType
    private let validator: PresetNameValidatorType

    private var validationError: PresetNameError? {
        validator.validate(name: name, for: mode.validationMode)
    }

    init(
        mode: PresetNameDialogMode,
        channelStrip: ChannelStripModelType,
        presets: PresetsModelType,
        validator: PresetNameValidatorType
    ) {
        self.name = mode.initialName
        self.mode = mode
        self.channelStrip = channelStrip
        self.presets = presets
        self.validator = validator
    }

    func commit() {
        guard canCommit else { return }
        switch mode {
        case .saveAs:
            if let preset = channelStrip.preset {
                presets.saveAsNew(name: name, preset: preset)
            }
        case .rename(let currentName):
            presets.rename(from: currentName, to: name)
        }
        isDismissed = true
    }

    func cancel() {
        isDismissed = true
    }
}

private extension PresetNameDialogMode {
    var initialName: String {
        switch self {
        case .saveAs: return ""
        case .rename(let currentName): return currentName
        }
    }

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
