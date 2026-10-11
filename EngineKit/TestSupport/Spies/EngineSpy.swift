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
    public var loadResult: Result<LoadedAudioUnit, EngineLoadError>

    public init(loadResult: Result<LoadedAudioUnit, EngineLoadError> = .failure(.audioUnitInstantiationFailed)) {
        self.loadResult = loadResult
    }

    /// Runs while the load is in flight, before the result is returned.
    public var onLoad: (@Sendable () async -> Void)?
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

    public func unload(at position: Int) async {
        calls.append(.unload(position))
    }

    public func reload() async {
        calls.append(.reload)
    }
}
