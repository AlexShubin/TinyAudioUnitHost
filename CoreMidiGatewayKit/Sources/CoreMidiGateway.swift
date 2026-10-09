//
//  CoreMidiGateway.swift
//  CoreMidiGatewayKit
//
//  Created by Alex Shubin on 09.10.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioUnitsKit
import CoreMIDI

public protocol CoreMidiGatewayType: Sendable {
    func createClient(name: String, onSetupChange: @escaping @Sendable () async -> Void) -> UInt32?
    func disposeClient(_ client: UInt32)
    var sourceCount: Int { get }
    func source(at index: Int) -> UInt32
    func displayName(of source: UInt32) -> String?
    func uid(of source: UInt32) -> Int32?
    func isOffline(_ source: UInt32) -> Bool
    func createInputPort(client: UInt32, name: String, audioUnit: LoadedAudioUnit) -> UInt32?
    func connect(source: UInt32, to port: UInt32)
    func disconnect(source: UInt32, from port: UInt32)
    func disposePort(_ port: UInt32)
}

public extension CoreMidiGatewayType {
    func createClient(name: String) -> UInt32? {
        createClient(name: name, onSetupChange: {})
    }
}

struct CoreMidiGateway: CoreMidiGatewayType {
    func createClient(name: String, onSetupChange: @escaping @Sendable () async -> Void) -> UInt32? {
        var client: MIDIClientRef = 0
        let status = MIDIClientCreateWithBlock(name as CFString, &client) { notification in
            guard notification.pointee.messageID == .msgSetupChanged else { return }
            Task { await onSetupChange() }
        }
        return status == noErr ? client : nil
    }

    func disposeClient(_ client: UInt32) {
        MIDIClientDispose(client)
    }

    var sourceCount: Int {
        MIDIGetNumberOfSources()
    }

    func source(at index: Int) -> UInt32 {
        MIDIGetSource(index)
    }

    func displayName(of source: UInt32) -> String? {
        var result: Unmanaged<CFString>?
        guard MIDIObjectGetStringProperty(source, kMIDIPropertyDisplayName, &result) == noErr,
              let result
        else { return nil }
        let string = result.takeRetainedValue() as String
        return string.isEmpty ? nil : string
    }

    func uid(of source: UInt32) -> Int32? {
        var value: Int32 = 0
        guard MIDIObjectGetIntegerProperty(source, kMIDIPropertyUniqueID, &value) == noErr
        else { return nil }
        return value
    }

    func isOffline(_ source: UInt32) -> Bool {
        var value: Int32 = 0
        guard MIDIObjectGetIntegerProperty(source, kMIDIPropertyOffline, &value) == noErr
        else { return false }
        return value != 0
    }

    func createInputPort(client: UInt32, name: String, audioUnit: LoadedAudioUnit) -> UInt32? {
        var port: MIDIPortRef = 0
        let status = MIDIInputPortCreateWithProtocol(
            client,
            name as CFString,
            ._1_0,
            &port
        ) { eventList, _ in
            audioUnit.scheduleMIDIEventList(eventList)
        }
        return status == noErr ? port : nil
    }

    func connect(source: UInt32, to port: UInt32) {
        MIDIPortConnectSource(port, source, nil)
    }

    func disconnect(source: UInt32, from port: UInt32) {
        MIDIPortDisconnectSource(port, source)
    }

    func disposePort(_ port: UInt32) {
        MIDIPortDispose(port)
    }
}
