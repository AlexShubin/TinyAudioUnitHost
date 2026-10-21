//
//  AudioConnectorSpy.swift
//  SessionKitTests
//
//  Created by Alex Shubin on 14.10.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AVFoundation
@testable import SessionKit

final class AudioConnectorSpy: AudioConnectorType, @unchecked Sendable {
    enum Calls: Equatable {
        case bind(SessionHardwareSettings.Audio)
        case connect(input: AVAudioNode?, output: AVAudioUnit, settings: SessionHardwareSettings.Audio)
        case disconnect
    }

    private(set) var calls: [Calls] = []

    var bindResult = true
    func bind(_ settings: SessionHardwareSettings.Audio, in engine: AVAudioEngineType) -> Bool {
        calls.append(.bind(settings))
        return bindResult
    }

    func connect(input: AVAudioNode?, output: AVAudioUnit, to settings: SessionHardwareSettings.Audio, in engine: AVAudioEngineType) {
        calls.append(.connect(input: input, output: output, settings: settings))
    }

    func disconnect(in engine: AVAudioEngineType) {
        calls.append(.disconnect)
    }
}
