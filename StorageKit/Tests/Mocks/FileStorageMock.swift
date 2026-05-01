//
//  FileStorageMock.swift
//  StorageKitTests
//
//  Created by Alex Shubin on 30.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import Foundation
@testable import StorageKit

final class FileStorageMock: FileStorageType, @unchecked Sendable {
    enum Calls: Equatable {
        case read(String)
        case write(String)
    }

    private(set) var calls: [Calls] = []
    var storage: [String: Data] = [:]

    init(storage: [String: Data] = [:]) {
        self.storage = storage
    }

    func read<T: Decodable>(_ type: T.Type, key: String) -> T? {
        calls.append(.read(key))
        guard let data = storage[key] else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    func write<T: Encodable>(_ value: T, key: String) {
        calls.append(.write(key))
        guard let data = try? JSONEncoder().encode(value) else { return }
        storage[key] = data
    }
}
