//
//  PluginChainSpy.swift
//  SessionKitTests
//
//  Created by Alex Shubin on 04.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioUnitsKit
import Foundation
@testable import SessionKit

final class PluginChainSpy: PluginChainType, @unchecked Sendable {
    enum Calls: Equatable, Sendable {
        case load(PluginChainSlot, at: Int)
        case load([PluginChainSlot?])
        case unload(Int)
        case reconnect
    }

    private(set) var calls: [Calls] = []

    /// Runs while the load is in flight, before the result is returned.
    var onLoad: (@Sendable () async -> Void)?
    var loadResult: Result<LoadedAudioUnit, PluginChainLoadError> = .failure(.audioUnitInstantiationFailed)
    func load(_ slot: PluginChainSlot, at position: Int) async throws(PluginChainLoadError) -> LoadedAudioUnit {
        calls.append(.load(slot, at: position))
        await onLoad?()
        return try loadResult.get()
    }

    var loadSlotsResult: [Result<LoadedAudioUnit, PluginChainLoadError>?] = []
    func load(_ slots: [PluginChainSlot?]) async -> [Result<LoadedAudioUnit, PluginChainLoadError>?] {
        calls.append(.load(slots))
        return loadSlotsResult
    }

    /// Runs while the unload is in flight.
    var onUnload: (@Sendable () async -> Void)?
    func unload(at position: Int) async {
        calls.append(.unload(position))
        await onUnload?()
    }

    func reconnect() async {
        calls.append(.reconnect)
    }
}
