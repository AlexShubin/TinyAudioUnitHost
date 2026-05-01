//
//  FileStorage.swift
//  StorageKit
//
//  Created by Alex Shubin on 30.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import Foundation

protocol FileStorageType: Sendable {
    func read<T: Decodable>(_ type: T.Type, key: String) -> T?
    func write<T: Encodable>(_ value: T, key: String)
}

final class FileStorage: FileStorageType {
    private let directory: URL

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let bundleID = Bundle.main.bundleIdentifier ?? "TinyAudioUnitHost"
        self.directory = base.appending(path: bundleID)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    func read<T: Decodable>(_ type: T.Type, key: String) -> T? {
        let url = url(for: key)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    func write<T: Encodable>(_ value: T, key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        try? data.write(to: url(for: key), options: .atomic)
    }

    private func url(for key: String) -> URL {
        directory.appending(path: "\(key).json")
    }
}
