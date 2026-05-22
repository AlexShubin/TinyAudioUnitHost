//
//  FileStorageMock.swift
//  StorageKitTests
//
//  Created by Alex Shubin on 30.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

@testable import StorageKit

final class FileStorageMock: FileStorageType, @unchecked Sendable {
    var storage: [String: Any] = [:]

    init(storage: [String: Any] = [:]) {
        self.storage = storage
    }

    func read<T: Decodable>(_ type: T.Type, at relativePath: String) -> T? {
        storage[relativePath] as? T
    }

    func write<T: Encodable>(_ value: T, at relativePath: String) {
        storage[relativePath] = value
    }

    func delete(at relativePath: String) {
        storage.removeValue(forKey: relativePath)
    }

    func list(directory relativePath: String) -> [String] {
        let prefix = relativePath + "/"
        return storage.keys
            .filter { $0.hasPrefix(prefix) }
            .map { String($0.dropFirst(prefix.count)) }
    }

    func move(from: String, to: String) {
        guard let value = storage.removeValue(forKey: from) else { return }
        storage[to] = value
    }
}
