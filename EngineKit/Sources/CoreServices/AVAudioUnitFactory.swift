//
//  AVAudioUnitFactory.swift
//  EngineKit
//
//  Created by Alex Shubin on 30.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

@preconcurrency import AVFoundation

protocol AVAudioUnitFactoryType {
    func instantiate(
        with description: AudioComponentDescription,
        options: AudioComponentInstantiationOptions
    ) async throws -> AVAudioUnit
}

final class AVAudioUnitFactory: AVAudioUnitFactoryType {
    func instantiate(
        with description: AudioComponentDescription,
        options: AudioComponentInstantiationOptions
    ) async throws -> AVAudioUnit {
        try await AVAudioUnit.instantiate(with: description, options: options)
    }
}
