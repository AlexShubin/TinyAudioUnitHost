//
//  CoreMidiGatewayMock.swift
//  AudioSettingsKitTests
//
//  Created by Alex Shubin on 02.07.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

@testable import AudioSettingsKit

final class CoreMidiGatewayMock: CoreMidiGatewayType, @unchecked Sendable {
    enum Calls: Equatable {
        case sourceCount
        case source(Int)
        case displayName(UInt32)
        case uid(UInt32)
    }

    private(set) var calls: [Calls] = []

    var sourceCountResult = 0
    var sourceCount: Int {
        calls.append(.sourceCount)
        return sourceCountResult
    }

    var sourcesByIndex: [Int: UInt32] = [:]
    func source(at index: Int) -> UInt32 {
        calls.append(.source(index))
        return sourcesByIndex[index] ?? 0
    }

    var displayNameBySource: [UInt32: String] = [:]
    func displayName(of source: UInt32) -> String? {
        calls.append(.displayName(source))
        return displayNameBySource[source]
    }

    var uidBySource: [UInt32: Int32] = [:]
    func uid(of source: UInt32) -> Int32? {
        calls.append(.uid(source))
        return uidBySource[source]
    }
}
