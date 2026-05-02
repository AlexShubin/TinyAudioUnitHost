//
//  AVAudioEngineType.swift
//  EngineKit
//
//  Created by Alex Shubin on 30.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AVFoundation

protocol AVAudioEngineType: AnyObject {
    var inputAudioUnit: AudioUnit? { get }
    var outputAudioUnit: AudioUnit? { get }
    var hardwareOutputFormat: AVAudioFormat { get }

    func attach(_ node: AVAudioNode)
    func detach(_ node: AVAudioNode)
    func start() throws
    func stop()
    func connect(_ node1: AVAudioNode, to node2: AVAudioNode, format: AVAudioFormat?)
    func connectHardwareInput(to node: AVAudioNode, format: AVAudioFormat?)
    func connectToMainMixer(_ node: AVAudioNode, format: AVAudioFormat?)
    func disconnectNodeInput(_ node: AVAudioNode)
    func disconnectNodeOutput(_ node: AVAudioNode)
    func disconnectHardwareInput()
    func disconnectMainMixerInput()
}

extension AVAudioEngine: AVAudioEngineType {
    var inputAudioUnit: AudioUnit? { inputNode.audioUnit }
    var outputAudioUnit: AudioUnit? { outputNode.audioUnit }
    var hardwareOutputFormat: AVAudioFormat { outputNode.outputFormat(forBus: 0) }

    func connectHardwareInput(to node: AVAudioNode, format: AVAudioFormat?) {
        connect(inputNode, to: node, format: format)
    }

    func connectToMainMixer(_ node: AVAudioNode, format: AVAudioFormat?) {
        connect(node, to: mainMixerNode, format: format)
    }

    func disconnectHardwareInput() {
        disconnectNodeOutput(inputNode)
    }

    func disconnectMainMixerInput() {
        disconnectNodeInput(mainMixerNode)
    }
}
