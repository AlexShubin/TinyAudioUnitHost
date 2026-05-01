//
//  FileStorageMock.swift
//  StorageKitTests
//
//  Created by Alex Shubin on 30.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

@testable import StorageKit

final class FileStorageMock: FileStorageType, @unchecked Sendable {
    enum Calls: Equatable {
        case read(String)
        case write(String)
    }

    private(set) var calls: [Calls] = []
    var storage: [String: Any] = [:]

    init(storage: [String: Any] = [:]) {
        self.storage = storage
    }

    func read<T: Decodable>(_ type: T.Type, key: String) -> T? {
        calls.append(.read(key))
        return storage[key] as? T
    }

    func write<T: Encodable>(_ value: T, key: String) {
        calls.append(.write(key))
        storage[key] = value
    }
}
