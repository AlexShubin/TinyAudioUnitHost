//
//  CoreMidiGatewaySpy.swift
//  AudioSettingsKitTests
//
//  Created by Alex Shubin on 02.07.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

@testable import AudioSettingsKit

final class CoreMidiGatewaySpy: CoreMidiGatewayType, @unchecked Sendable {
    enum Calls: Equatable {
        case createClient(String)
        case disposeClient(UInt32)
        case sourceCount
        case source(Int)
        case displayName(UInt32)
        case uid(UInt32)
        case isOffline(UInt32)
    }

    private(set) var calls: [Calls] = []

    var createClientResult: UInt32? = 1
    private(set) var setupChangeHandler: (@Sendable () async -> Void)?
    func createClient(name: String, onSetupChange: @escaping @Sendable () async -> Void) -> UInt32? {
        setupChangeHandler = onSetupChange
        calls.append(.createClient(name))
        return createClientResult
    }

    func disposeClient(_ client: UInt32) {
        calls.append(.disposeClient(client))
    }

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

    var offlineSources: Set<UInt32> = []
    func isOffline(_ source: UInt32) -> Bool {
        calls.append(.isOffline(source))
        return offlineSources.contains(source)
    }
}
