//
//  MidiDevicesProviderMock.swift
//  AudioSettingsKitTestSupport
//
//  Created by Alex Shubin on 02.07.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioSettingsKit

public final class MidiDevicesProviderMock: MidiDevicesProviderType, @unchecked Sendable {
    public enum Calls: Equatable {
        case devices
    }

    public private(set) var calls: [Calls] = []

    public init() {}

    public var devicesResult: [MidiDevice] = []
    public var devices: [MidiDevice] {
        calls.append(.devices)
        return devicesResult
    }
}
