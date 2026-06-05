//
//  AggregateDeviceFactoryMock.swift
//  AudioSettingsKitTests
//
//  Created by Alex Shubin on 04.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

@testable import AudioSettingsKit

final class AggregateDeviceFactoryMock: AggregateDeviceFactoryType, @unchecked Sendable {
    enum Calls: Equatable {
        case create(inputUID: String, outputUID: String)
        case destroy(UInt32)
        case destroyOrphans
    }

    private(set) var calls: [Calls] = []
    var createResult: UInt32?

    init(createResult: UInt32? = nil) {
        self.createResult = createResult
    }

    func create(inputUID: String, outputUID: String) -> UInt32? {
        calls.append(.create(inputUID: inputUID, outputUID: outputUID))
        return createResult
    }

    func destroy(id: UInt32) {
        calls.append(.destroy(id))
    }

    func destroyOrphans() {
        calls.append(.destroyOrphans)
    }
}
