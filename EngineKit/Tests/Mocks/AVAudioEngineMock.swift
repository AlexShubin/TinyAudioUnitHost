//
//  AVAudioEngineMock.swift
//  EngineKitTests
//
//  Created by Alex Shubin on 30.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AVFoundation
@testable import EngineKit

final class AVAudioEngineMock: AVAudioEngineType {
    enum Calls: Equatable {
        case attach(AVAudioNode)
        case detach(AVAudioNode)
        case start
        case stop
        case connect(AVAudioNode, AVAudioNode, AVAudioFormat?)
        case disconnectNodeInput(AVAudioNode)
        case disconnectNodeOutput(AVAudioNode)
    }

    private(set) var calls: [Calls] = []
    var startError: Error?

    private let backingEngine: AVAudioEngine

    var inputNode: AVAudioInputNode { backingEngine.inputNode }
    var outputNode: AVAudioOutputNode { backingEngine.outputNode }
    var mainMixerNode: AVAudioMixerNode { backingEngine.mainMixerNode }

    init(backingEngine: AVAudioEngine = AVAudioEngine(), startError: Error? = nil) {
        self.backingEngine = backingEngine
        self.startError = startError
    }

    func attach(_ node: AVAudioNode) {
        calls.append(.attach(node))
    }

    func detach(_ node: AVAudioNode) {
        calls.append(.detach(node))
    }

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

    func disconnectNodeInput(_ node: AVAudioNode) {
        calls.append(.disconnectNodeInput(node))
    }

    func disconnectNodeOutput(_ node: AVAudioNode) {
        calls.append(.disconnectNodeOutput(node))
    }
}
