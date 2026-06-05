//
//  AudioDevicesProviderMock.swift
//  AudioSettingsKitTestSupport
//
//  Created by Alex Shubin on 04.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioSettingsKit

public final class AudioDevicesProviderMock: AudioDevicesProviderType, @unchecked Sendable {
    public enum Calls: Equatable {
        case devices(AudioDeviceFilter)
        case device(UInt32)
    }

    public private(set) var calls: [Calls] = []
    public var devicesResult: [AudioDevice]
    public var deviceByID: [UInt32: AudioDevice]

    public init(
        devicesResult: [AudioDevice] = [],
        deviceByID: [UInt32: AudioDevice] = [:]
    ) {
        self.devicesResult = devicesResult
        self.deviceByID = deviceByID
    }

    public func devices(_ filter: AudioDeviceFilter) -> [AudioDevice] {
        calls.append(.devices(filter))
        return devicesResult
    }

    public func device(id: UInt32) -> AudioDevice? {
        calls.append(.device(id))
        return deviceByID[id]
    }
}
