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
        case connect(first: AVAudioUnit, last: AVAudioUnit, settings: SessionHardwareSettings.Audio)
        case disconnect
    }

    private(set) var calls: [Calls] = []

    var connectResult = true
    func connect(first: AVAudioUnit, last: AVAudioUnit, to settings: SessionHardwareSettings.Audio, in engine: AVAudioEngineType) -> Bool {
        calls.append(.connect(first: first, last: last, settings: settings))
        return connectResult
    }

    func disconnect(in engine: AVAudioEngineType) {
        calls.append(.disconnect)
    }
}
