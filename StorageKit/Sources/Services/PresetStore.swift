//
//  PresetStore.swift
//  StorageKit
//
//  Created by Alex Shubin on 05.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

public protocol PresetStoreType: Sendable {
    func load(name: String) async -> Preset?
    func save(_ preset: Preset, name: String) async
}

final actor PresetStore: PresetStoreType {
    private let fileStorage: FileStorageType

    init(fileStorage: FileStorageType) {
        self.fileStorage = fileStorage
    }

    func load(name: String) -> Preset? {
        fileStorage.read(Preset.self, at: path(for: name))
    }

    func save(_ preset: Preset, name: String) {
        fileStorage.write(preset, at: path(for: name))
    }

    private func path(for name: String) -> String {
        "presets/\(name)"
    }
}
