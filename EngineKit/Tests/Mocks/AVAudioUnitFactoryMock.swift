//
//  AVAudioUnitFactoryMock.swift
//  EngineKitTests
//
//  Created by Alex Shubin on 30.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AVFoundation
@testable import EngineKit

final class AVAudioUnitFactoryMock: AVAudioUnitFactoryType {
    enum Calls: Equatable {
        case instantiate(AudioComponentDescription, AudioComponentInstantiationOptions)
    }

    private(set) var calls: [Calls] = []
    var instantiateResult: Result<AVAudioUnit, Error>?

    init(instantiateResult: Result<AVAudioUnit, Error>? = nil) {
        self.instantiateResult = instantiateResult
    }

    func instantiate(
        with description: AudioComponentDescription,
        options: AudioComponentInstantiationOptions
    ) async throws -> AVAudioUnit {
        calls.append(.instantiate(description, options))
        guard let instantiateResult else {
            throw NSError(domain: "AVAudioUnitFactoryMock", code: -1)
        }
        return try instantiateResult.get()
    }
}

extension AudioComponentDescription: @retroactive Equatable {
    public static func == (lhs: AudioComponentDescription, rhs: AudioComponentDescription) -> Bool {
        lhs.componentType == rhs.componentType
            && lhs.componentSubType == rhs.componentSubType
            && lhs.componentManufacturer == rhs.componentManufacturer
            && lhs.componentFlags == rhs.componentFlags
            && lhs.componentFlagsMask == rhs.componentFlagsMask
    }
}
