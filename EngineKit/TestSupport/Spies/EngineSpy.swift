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
        case load(AudioUnitComponent, Data?)
        case reload
    }

    public private(set) var calls: [Calls] = []
    public var loadResult: Result<LoadedAudioUnit, EngineLoadError>
    public var reloadError: EngineLoadError?

    public init(
        loadResult: Result<LoadedAudioUnit, EngineLoadError> = .failure(.audioUnitInstantiationFailed),
        reloadError: EngineLoadError? = nil
    ) {
        self.loadResult = loadResult
        self.reloadError = reloadError
    }

    /// Runs while the load is in flight, before the result is returned.
    public var onLoad: (@Sendable () async -> Void)?
    public func load(component: AudioUnitComponent, state: Data?) async throws(EngineLoadError) -> LoadedAudioUnit {
        calls.append(.load(component, state))
        await onLoad?()
        return try loadResult.get()
    }

    public func reload() async throws(EngineLoadError) {
        calls.append(.reload)
        if let reloadError { throw reloadError }
    }
}
