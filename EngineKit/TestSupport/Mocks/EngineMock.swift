//
//  EngineMock.swift
//  EngineKitTestSupport
//
//  Created by Alex Shubin on 04.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioUnitsKit
import EngineKit
import Foundation

public actor EngineMock: EngineType {
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

    public func load(component: AudioUnitComponent, state: Data?) async throws -> LoadedAudioUnit {
        calls.append(.load(component, state))
        return try loadResult.get()
    }

    public func reload() async throws {
        calls.append(.reload)
        if let reloadError { throw reloadError }
    }

    public func setLoadResult(_ value: Result<LoadedAudioUnit, EngineLoadError>) {
        loadResult = value
    }

    public func setReloadError(_ value: EngineLoadError?) {
        reloadError = value
    }
}
