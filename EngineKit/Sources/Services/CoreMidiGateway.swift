//
//  CoreMidiGateway.swift
//  EngineKit
//
//  Created by Alex Shubin on 05.06.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioToolbox
import AudioUnitsKit
import CoreMIDI

protocol CoreMidiGatewayType: Sendable {
    func createClient(name: String) -> (client: UInt32, setupChanges: AsyncStream<Void>)?
    func createInputPort(
        client: UInt32,
        name: String,
        audioUnit: AUAudioUnitType
    ) -> UInt32?
    var sourceCount: Int { get }
    func source(at index: Int) -> UInt32
    func connect(source: UInt32, to port: UInt32)
    func disposePort(_ port: UInt32)
}

struct CoreMidiGateway: CoreMidiGatewayType {
    func createClient(name: String) -> (client: UInt32, setupChanges: AsyncStream<Void>)? {
        let (stream, continuation) = AsyncStream<Void>.makeStream()
        var client: MIDIClientRef = 0
        let status = MIDIClientCreateWithBlock(name as CFString, &client) { notification in
            if notification.pointee.messageID == .msgSetupChanged {
                continuation.yield()
            }
        }
        guard status == noErr else {
            continuation.finish()
            return nil
        }
        return (client, stream)
    }

    func createInputPort(
        client: UInt32,
        name: String,
        audioUnit: AUAudioUnitType
    ) -> UInt32? {
        var port: MIDIPortRef = 0
        let status = MIDIInputPortCreateWithProtocol(
            client,
            name as CFString,
            ._1_0,
            &port
        ) { eventList, _ in
            _ = audioUnit.scheduleMIDIEventListBlock?(AUEventSampleTimeImmediate, 0, eventList)
        }
        return status == noErr ? port : nil
    }

    var sourceCount: Int {
        MIDIGetNumberOfSources()
    }

    func source(at index: Int) -> UInt32 {
        MIDIGetSource(index)
    }

    func connect(source: UInt32, to port: UInt32) {
        MIDIPortConnectSource(port, source, nil)
    }

    func disposePort(_ port: UInt32) {
        MIDIPortDispose(port)
    }
}
