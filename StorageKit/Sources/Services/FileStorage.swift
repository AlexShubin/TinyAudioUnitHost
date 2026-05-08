//
//  FileStorage.swift
//  StorageKit
//
//  Created by Alex Shubin on 30.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import Foundation

protocol FileStorageType: Sendable {
    func read<T: Decodable>(_ type: T.Type, at relativePath: String) -> T?
    func write<T: Encodable>(_ value: T, at relativePath: String)
    func delete(at relativePath: String)
}

final class FileStorage: FileStorageType {
    private let directory: URL
    private let jsonDecoder = JSONDecoder()
    private let jsonEncoder = JSONEncoder()

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let bundleID = Bundle.main.bundleIdentifier!
        self.directory = base.appending(path: bundleID)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    func read<T: Decodable>(_ type: T.Type, at relativePath: String) -> T? {
        guard let data = try? Data(contentsOf: url(for: relativePath)) else { return nil }
        return try? jsonDecoder.decode(T.self, from: data)
    }

    func write<T: Encodable>(_ value: T, at relativePath: String) {
        let url = url(for: relativePath)
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        guard let data = try? jsonEncoder.encode(value) else { return }
        try? data.write(to: url, options: .atomic)
    }

    func delete(at relativePath: String) {
        try? FileManager.default.removeItem(at: url(for: relativePath))
    }

    private func url(for relativePath: String) -> URL {
        directory.appending(path: "\(relativePath).json")
    }
}
