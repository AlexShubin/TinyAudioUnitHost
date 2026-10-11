//
//  AVAudioUnitFactorySpy.swift
//  EngineKitTests
//
//  Created by Alex Shubin on 30.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AVFoundation
@testable import EngineKit

final class AVAudioUnitFactorySpy: AVAudioUnitFactoryType, @unchecked Sendable {
    enum Calls: Equatable {
        case instantiate(AudioComponentDescription, AudioComponentInstantiationOptions)
    }

    private(set) var calls: [Calls] = []

    /// Runs while the instantiation is in flight, before the result is returned.
    var onInstantiate: (@Sendable () async -> Void)?
    var instantiateResult: Result<AVAudioUnit, Error> = .failure(NSError(domain: "AVAudioUnitFactorySpy", code: -1))
    /// Per-description results for tests that instantiate several units in one call; falls back to `instantiateResult`.
    var instantiateResultByDescription: [AudioComponentDescription: Result<AVAudioUnit, Error>] = [:]
    func instantiate(
        with description: AudioComponentDescription,
        options: AudioComponentInstantiationOptions
    ) async throws -> AVAudioUnit {
        calls.append(.instantiate(description, options))
        await onInstantiate?()
        return try (instantiateResultByDescription[description] ?? instantiateResult).get()
    }
}

extension AudioComponentDescription: @retroactive Hashable {
    public static func == (lhs: AudioComponentDescription, rhs: AudioComponentDescription) -> Bool {
        lhs.componentType == rhs.componentType
            && lhs.componentSubType == rhs.componentSubType
            && lhs.componentManufacturer == rhs.componentManufacturer
            && lhs.componentFlags == rhs.componentFlags
            && lhs.componentFlagsMask == rhs.componentFlagsMask
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(componentType)
        hasher.combine(componentSubType)
        hasher.combine(componentManufacturer)
        hasher.combine(componentFlags)
        hasher.combine(componentFlagsMask)
    }
}
