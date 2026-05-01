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
        guard let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            preconditionFailure("applicationSupportDirectory unavailable; this should never happen for an .app bundle")
        }
        guard let bundleID = Bundle.main.bundleIdentifier else {
            preconditionFailure("Bundle.main.bundleIdentifier is nil; this should never happen for an .app bundle")
        }
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
