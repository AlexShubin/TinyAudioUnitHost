//
//  ChannelStripSpy.swift
//  SessionKitTests
//
//  Created by Alex Shubin on 04.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioUnitsKit
import Foundation
@testable import SessionKit

final class ChannelStripSpy: ChannelStripType, @unchecked Sendable {
    enum Calls: Equatable, Sendable {
        case load(ChannelStripSlot, at: Int)
        case load([ChannelStripSlot?])
        case unload(Int)
        case reconnect
    }

    private(set) var calls: [Calls] = []

    /// Runs while the load is in flight, before the result is returned.
    var onLoad: (@Sendable () async -> Void)?
    var loadResult: Result<LoadedAudioUnit, ChannelStripLoadError> = .failure(.audioUnitInstantiationFailed)
    func load(_ slot: ChannelStripSlot, at position: Int) async throws(ChannelStripLoadError) -> LoadedAudioUnit {
        calls.append(.load(slot, at: position))
        await onLoad?()
        return try loadResult.get()
    }

    var loadSlotsResult: [Result<LoadedAudioUnit, ChannelStripLoadError>?] = []
    func load(_ slots: [ChannelStripSlot?]) async -> [Result<LoadedAudioUnit, ChannelStripLoadError>?] {
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
