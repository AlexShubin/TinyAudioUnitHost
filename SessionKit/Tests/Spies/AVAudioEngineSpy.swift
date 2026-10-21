//
//  AVAudioEngineSpy.swift
//  SessionKitTests
//
//  Created by Alex Shubin on 30.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AVFoundation
@testable import SessionKit

final class AVAudioEngineSpy: AVAudioEngineType, @unchecked Sendable {
    enum Calls: Equatable {
        case attach(AVAudioNode)
        case detach(AVAudioNode)
        case start
        case stop
        case connect(AVAudioNode, AVAudioNode, AVAudioFormat?)
        case connectHardwareInput(AVAudioNode, AVAudioFormat?)
        case connectToMainMixer(AVAudioNode, AVAudioFormat?)
        case disconnectHardwareInput
        case disconnectMainMixerInput
    }

    private(set) var calls: [Calls] = []

    var inputAudioUnit: AudioUnit?
    var outputAudioUnit: AudioUnit?
    var hardwareOutputFormat: AVAudioFormat = AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 2)!

    func attach(_ node: AVAudioNode) {
        calls.append(.attach(node))
    }

    func detach(_ node: AVAudioNode) {
        calls.append(.detach(node))
    }

    var startError: Error?
    func start() throws {
        calls.append(.start)
        if let startError {
            throw startError
        }
    }

    func stop() {
        calls.append(.stop)
    }

    func connect(_ node1: AVAudioNode, to node2: AVAudioNode, format: AVAudioFormat?) {
        calls.append(.connect(node1, node2, format))
    }

    func connectHardwareInput(to node: AVAudioNode, format: AVAudioFormat?) {
        calls.append(.connectHardwareInput(node, format))
    }

    func connectToMainMixer(_ node: AVAudioNode, format: AVAudioFormat?) {
        calls.append(.connectToMainMixer(node, format))
    }

    func disconnectHardwareInput() {
        calls.append(.disconnectHardwareInput)
    }

    func disconnectMainMixerInput() {
        calls.append(.disconnectMainMixerInput)
    }
}
