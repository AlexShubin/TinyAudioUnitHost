//
//  PluginChainSpy.swift
//  SessionKitTestSupport
//
//  Created by Alex Shubin on 04.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioUnitsKit
import Foundation
import SessionKit

public final class PluginChainSpy: PluginChainType, @unchecked Sendable {
    public enum Calls: Equatable, Sendable {
        case load(PluginChainSlot, at: Int)
        case load([PluginChainSlot?])
        case unload(Int)
        case reconnect
    }

    public private(set) var calls: [Calls] = []

    public init() {}

    /// Runs while the load is in flight, before the result is returned.
    public var onLoad: (@Sendable () async -> Void)?
    public var loadResult: Result<LoadedAudioUnit, PluginChainLoadError> = .failure(.audioUnitInstantiationFailed)
    public func load(_ slot: PluginChainSlot, at position: Int) async throws(PluginChainLoadError) -> LoadedAudioUnit {
        calls.append(.load(slot, at: position))
        await onLoad?()
        return try loadResult.get()
    }

    public var loadSlotsResult: [Result<LoadedAudioUnit, PluginChainLoadError>?] = []
    public func load(_ slots: [PluginChainSlot?]) async -> [Result<LoadedAudioUnit, PluginChainLoadError>?] {
        calls.append(.load(slots))
        return loadSlotsResult
    }

    /// Runs while the unload is in flight.
    public var onUnload: (@Sendable () async -> Void)?
    public func unload(at position: Int) async {
        calls.append(.unload(position))
        await onUnload?()
    }

    public func reconnect() async {
        calls.append(.reconnect)
    }
}
