//
//  PresetProviderMock.swift
//  PresetKitTestSupport
//
//  Created by Alex Shubin on 09.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioUnitsKit
import Foundation
import PresetKit

public final class PresetProviderMock: PresetProviderType, @unchecked Sendable {
    public enum Calls: Equatable, Sendable {
        case presets
        case activeName
        case setActive(String?)
        case load(name: String)
        case save(Preset)
        case saveAs(Preset)
        case rename(from: String, to: String)
        case delete(name: String)
    }

    public private(set) var calls: [Calls] = []
    public var storedPresets: [String: Preset]
    public var currentActiveName: String?
    public var saveAsResult: Result<Preset, PresetNameError>?
    public var renameResult: Result<Void, PresetNameError>?

    public init(
        presets: [String: Preset] = [:],
        activeName: String? = nil
    ) {
        self.storedPresets = presets
        self.currentActiveName = activeName
    }

    public var presets: [Preset] {
        calls.append(.presets)
        return storedPresets.values.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    public var activeName: String? {
        calls.append(.activeName)
        return currentActiveName
    }

    public func setActive(_ name: String?) {
        currentActiveName = name
        calls.append(.setActive(name))
    }

    public func load(name: String) -> Preset? {
        calls.append(.load(name: name))
        return storedPresets[name]
    }

    public func save(_ preset: Preset) {
        storedPresets[preset.name] = preset
        calls.append(.save(preset))
    }

    public func saveAs(_ preset: Preset) -> Result<Preset, PresetNameError> {
        calls.append(.saveAs(preset))
        if let saveAsResult { return saveAsResult }
        storedPresets[preset.name] = preset
        return .success(preset)
    }

    public func rename(from oldName: String, to newName: String) -> Result<Void, PresetNameError> {
        calls.append(.rename(from: oldName, to: newName))
        if let renameResult { return renameResult }
        if let existing = storedPresets.removeValue(forKey: oldName) {
            storedPresets[newName] = Preset(
                name: newName,
                component: existing.component,
                state: existing.state
            )
        }
        if currentActiveName == oldName {
            currentActiveName = newName
        }
        return .success(())
    }

    public func delete(name: String) {
        storedPresets.removeValue(forKey: name)
        if currentActiveName == name {
            currentActiveName = nil
        }
        calls.append(.delete(name: name))
    }
}
