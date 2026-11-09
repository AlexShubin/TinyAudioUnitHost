//
//  AudioConnectorSpy.swift
//  ChannelStripKitTests
//
//  Created by Alex Shubin on 14.10.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AVFoundation
@testable import ChannelStripKit

final class AudioConnectorSpy: AudioConnectorType, @unchecked Sendable {
    enum Calls: Equatable {
        case bind(ChannelStripHardwareSettings.Audio)
        case connect(input: AVAudioNode?, output: AVAudioUnit, settings: ChannelStripHardwareSettings.Audio)
        case disconnect
    }

    private(set) var calls: [Calls] = []

    var bindResult = true
    func bind(_ settings: ChannelStripHardwareSettings.Audio, in engine: AVAudioEngineType) -> Bool {
        calls.append(.bind(settings))
        return bindResult
    }

    func connect(input: AVAudioNode?, output: AVAudioUnit, to settings: ChannelStripHardwareSettings.Audio, in engine: AVAudioEngineType) {
        calls.append(.connect(input: input, output: output, settings: settings))
    }

    func disconnect(in engine: AVAudioEngineType) {
        calls.append(.disconnect)
    }
}
