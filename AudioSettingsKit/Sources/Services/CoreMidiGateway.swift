//
//  CoreMidiGateway.swift
//  AudioSettingsKit
//
//  Created by Alex Shubin on 02.07.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import CoreMIDI

protocol CoreMidiGatewayType: Sendable {
    var sourceCount: Int { get }
    func source(at index: Int) -> UInt32
    func displayName(of source: UInt32) -> String?
    func uid(of source: UInt32) -> Int32?
}

struct CoreMidiGateway: CoreMidiGatewayType {
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
}
