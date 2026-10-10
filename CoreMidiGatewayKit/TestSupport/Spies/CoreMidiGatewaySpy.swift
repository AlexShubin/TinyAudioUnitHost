//
//  CoreMidiGatewaySpy.swift
//  CoreMidiGatewayKitTestSupport
//
//  Created by Alex Shubin on 09.10.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioUnitsKit
import Common
import CoreMidiGatewayKit

public final class CoreMidiGatewaySpy: CoreMidiGatewayType, @unchecked Sendable {
    public enum Calls: Equatable {
        case observeSetupChanges
        case createClient(String)
        case disposeClient(UInt32)
        case sourceCount
        case source(Int)
        case displayName(UInt32)
        case uid(UInt32)
        case isOffline(UInt32)
        case createInputPort(UInt32, String, LoadedAudioUnit)
        case connect(UInt32, UInt32)
        case disconnect(UInt32, UInt32)
        case disposePort(UInt32)
    }

    public private(set) var calls: [Calls] = []

    public init() {}

    public private(set) var setupChangeHandler: (@Sendable () async -> Void)?
    public func observeSetupChanges(_ handler: @escaping @Sendable () async -> Void) -> Cancellation {
        setupChangeHandler = handler
        calls.append(.observeSetupChanges)
        return Cancellation {}
    }

    public var createClientResult: UInt32? = 1
    public func createClient(name: String) -> UInt32? {
        calls.append(.createClient(name))
        return createClientResult
    }

    public func disposeClient(_ client: UInt32) {
        calls.append(.disposeClient(client))
    }

    public var sourceCountResult = 0
    public var sourceCount: Int {
        calls.append(.sourceCount)
        return sourceCountResult
    }

    public var sourcesByIndex: [Int: UInt32] = [:]
    public func source(at index: Int) -> UInt32 {
        calls.append(.source(index))
        return sourcesByIndex[index] ?? 0
    }

    public var displayNameBySource: [UInt32: String] = [:]
    public func displayName(of source: UInt32) -> String? {
        calls.append(.displayName(source))
        return displayNameBySource[source]
    }

    public var uidBySource: [UInt32: Int32] = [:]
    public func uid(of source: UInt32) -> Int32? {
        calls.append(.uid(source))
        return uidBySource[source]
    }

    public var offlineSources: Set<UInt32> = []
    public func isOffline(_ source: UInt32) -> Bool {
        calls.append(.isOffline(source))
        return offlineSources.contains(source)
    }

    public var createInputPortResult: UInt32? = 1
    public func createInputPort(client: UInt32, name: String, audioUnit: LoadedAudioUnit) -> UInt32? {
        calls.append(.createInputPort(client, name, audioUnit))
        return createInputPortResult
    }

    public func connect(source: UInt32, to port: UInt32) {
        calls.append(.connect(source, port))
    }

    public func disconnect(source: UInt32, from port: UInt32) {
        calls.append(.disconnect(source, port))
    }

    public func disposePort(_ port: UInt32) {
        calls.append(.disposePort(port))
    }
}
