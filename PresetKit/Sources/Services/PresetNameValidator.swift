//
//  PresetNameValidator.swift
//  PresetKit
//
//  Created by Alex Shubin on 19.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import Foundation
import StorageKit

public enum ValidationMode: Sendable, Equatable {
    case saveAs
    case rename(currentName: String)
}

public protocol PresetNameValidatorType: Sendable {
    func validate(name: String, for mode: ValidationMode) -> PresetNameError?
}

struct PresetNameValidator: PresetNameValidatorType {
    private let rawStore: RawPresetStoreType

    init(rawStore: RawPresetStoreType) {
        self.rawStore = rawStore
    }

    func validate(name: String, for mode: ValidationMode) -> PresetNameError? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return .empty }
        if trimmed.contains("/") || trimmed.contains(":") || trimmed.hasPrefix(".") {
            return .invalidCharacter
        }
        let existing: [String]
        switch mode {
        case .saveAs:
            existing = rawStore.names
        case .rename(let currentName):
            existing = rawStore.names.filter { $0 != currentName }
        }
        let collision = existing.contains {
            $0.localizedCaseInsensitiveCompare(trimmed) == .orderedSame
        }
        if collision { return .duplicate }
        return nil
    }
}
