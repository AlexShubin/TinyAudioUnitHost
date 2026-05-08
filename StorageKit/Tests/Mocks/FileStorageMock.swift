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
}
