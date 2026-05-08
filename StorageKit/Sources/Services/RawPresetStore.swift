//
//  RawPresetStore.swift
//  StorageKit
//
//  Created by Alex Shubin on 05.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

public protocol RawPresetStoreType: Sendable {
    func load(name: String) async -> RawPreset?
    func save(_ preset: RawPreset, name: String) async
    func delete(name: String) async
}

final actor RawPresetStore: RawPresetStoreType {
    private let fileStorage: FileStorageType

    init(fileStorage: FileStorageType) {
        self.fileStorage = fileStorage
    }

    func load(name: String) -> RawPreset? {
        fileStorage.read(RawPreset.self, at: path(for: name))
    }

    func save(_ preset: RawPreset, name: String) {
        fileStorage.write(preset, at: path(for: name))
    }

    func delete(name: String) {
        fileStorage.delete(at: path(for: name))
    }

    private func path(for name: String) -> String {
        "presets/\(name)"
    }
}
