//
//  RawPresetStore.swift
//  StorageKit
//
//  Created by Alex Shubin on 05.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

public protocol RawPresetStoreType: Sendable {
    var names: [String] { get }
    var activePreset: RawActivePresetState? { get }
    func load(name: String) -> RawPreset?
    func save(_ preset: RawPreset, name: String)
    func rename(from: String, to: String)
    func delete(name: String)
    func saveActivePreset(_ state: RawActivePresetState)
    func deleteActivePreset()
}

struct RawPresetStore: RawPresetStoreType {
    private static let presetsDirectory = "presets"
    private static let activePresetPath = "active_preset"

    private let fileStorage: FileStorageType

    init(fileStorage: FileStorageType) {
        self.fileStorage = fileStorage
    }

    var names: [String] {
        fileStorage.list(directory: Self.presetsDirectory)
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    var activePreset: RawActivePresetState? {
        fileStorage.read(RawActivePresetState.self, at: Self.activePresetPath)
    }

    func load(name: String) -> RawPreset? {
        fileStorage.read(RawPreset.self, at: path(for: name))
    }

    func save(_ preset: RawPreset, name: String) {
        fileStorage.write(preset, at: path(for: name))
    }

    func rename(from: String, to: String) {
        fileStorage.move(from: path(for: from), to: path(for: to))
    }

    func delete(name: String) {
        fileStorage.delete(at: path(for: name))
    }

    func saveActivePreset(_ state: RawActivePresetState) {
        fileStorage.write(state, at: Self.activePresetPath)
    }

    func deleteActivePreset() {
        fileStorage.delete(at: Self.activePresetPath)
    }

    private func path(for name: String) -> String {
        "\(Self.presetsDirectory)/\(name)"
    }
}
