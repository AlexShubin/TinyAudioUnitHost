//
//  AVAudioEngineType.swift
//  EngineKit
//
//  Created by Alex Shubin on 30.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

@preconcurrency import AVFoundation

protocol AVAudioEngineType: AnyObject {
    var inputNode: AVAudioInputNode { get }
    var outputNode: AVAudioOutputNode { get }
    var mainMixerNode: AVAudioMixerNode { get }

    func attach(_ node: AVAudioNode)
    func detach(_ node: AVAudioNode)
    func start() throws
    func stop()
    func connect(_ node1: AVAudioNode, to node2: AVAudioNode, format: AVAudioFormat?)
    func disconnectNodeInput(_ node: AVAudioNode)
    func disconnectNodeOutput(_ node: AVAudioNode)
}

extension AVAudioEngine: AVAudioEngineType {}
