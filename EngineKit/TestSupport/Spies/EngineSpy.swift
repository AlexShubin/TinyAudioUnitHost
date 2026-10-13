//
//  EngineSpy.swift
//  EngineKitTestSupport
//
//  Created by Alex Shubin on 04.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioUnitsKit
import EngineKit
import Foundation

public final class EngineSpy: EngineType, @unchecked Sendable {
    public enum Calls: Equatable, Sendable {
        case load(EnginePluginSlot, at: Int)
        case load([EnginePluginSlot?])
        case unload(Int)
        case reload
    }

    public private(set) var calls: [Calls] = []

    public init() {}

    /// Runs while the load is in flight, before the result is returned.
    public var onLoad: (@Sendable () async -> Void)?
    public var loadResult: Result<LoadedAudioUnit, EngineLoadError> = .failure(.audioUnitInstantiationFailed)
    public func load(_ slot: EnginePluginSlot, at position: Int) async throws(EngineLoadError) -> LoadedAudioUnit {
        calls.append(.load(slot, at: position))
        await onLoad?()
        return try loadResult.get()
    }

    public var loadSlotsResult: [Result<LoadedAudioUnit, EngineLoadError>?] = []
    public func load(_ slots: [EnginePluginSlot?]) async -> [Result<LoadedAudioUnit, EngineLoadError>?] {
        calls.append(.load(slots))
        return loadSlotsResult
    }

    /// Runs while the unload is in flight.
    public var onUnload: (@Sendable () async -> Void)?
    public func unload(at position: Int) async {
        calls.append(.unload(position))
        await onUnload?()
    }

    public func reload() async {
        calls.append(.reload)
    }
}
