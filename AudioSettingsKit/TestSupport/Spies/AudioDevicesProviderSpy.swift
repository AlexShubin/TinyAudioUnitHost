//
//  AudioDevicesProviderSpy.swift
//  AudioSettingsKitTestSupport
//
//  Created by Alex Shubin on 02.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioSettingsKit

public final class AudioDevicesProviderSpy: AudioDevicesProviderType, @unchecked Sendable {
    public enum Calls: Equatable {
        case scanDevices
        case device(UInt32)
    }

    public private(set) var calls: [Calls] = []

    public init() {}

    public var scanDevicesResult: [AudioDevice] = []
    @concurrent
    public func scanDevices() async -> [AudioDevice] {
        calls.append(.scanDevices)
        return scanDevicesResult
    }

    public var deviceByID: [UInt32: AudioDevice] = [:]
    public func device(id: UInt32) -> AudioDevice? {
        calls.append(.device(id))
        return deviceByID[id]
    }
}
