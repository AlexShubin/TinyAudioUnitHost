//
//  RawPresetStoreMock.swift
//  StorageKitTestSupport
//
//  Created by Alex Shubin on 05.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import StorageKit

public final class RawPresetStoreMock: RawPresetStoreType, @unchecked Sendable {
    public enum Calls: Equatable, Sendable {
        case names
        case load(name: String)
        case save(RawPreset, name: String)
        case rename(from: String, to: String)
        case delete(name: String)
        case activePreset
        case saveActivePreset(RawActivePresetState)
        case deleteActivePreset
    }

    public private(set) var calls: [Calls] = []
    public var presets: [String: RawPreset]
    public var currentActivePreset: RawActivePresetState?

    public init(
        presets: [String: RawPreset] = [:],
        activePreset: RawActivePresetState? = nil
    ) {
        self.presets = presets
        self.currentActivePreset = activePreset
    }

    public var names: [String] {
        calls.append(.names)
        return presets.keys.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    public var activePreset: RawActivePresetState? {
        calls.append(.activePreset)
        return currentActivePreset
    }

    public func load(name: String) -> RawPreset? {
        calls.append(.load(name: name))
        return presets[name]
    }

    public func save(_ preset: RawPreset, name: String) {
        presets[name] = preset
        calls.append(.save(preset, name: name))
    }

    public func rename(from oldName: String, to newName: String) {
        if let raw = presets.removeValue(forKey: oldName) {
            presets[newName] = raw
        }
        calls.append(.rename(from: oldName, to: newName))
    }

    public func delete(name: String) {
        presets.removeValue(forKey: name)
        calls.append(.delete(name: name))
    }

    public func saveActivePreset(_ state: RawActivePresetState) {
        currentActivePreset = state
        calls.append(.saveActivePreset(state))
    }

    public func deleteActivePreset() {
        currentActivePreset = nil
        calls.append(.deleteActivePreset)
    }
}
