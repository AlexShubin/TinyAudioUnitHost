//
//  AudioDevicesProviderMock.swift
//  AudioSettingsKitTestSupport
//
//  Created by Alex Shubin on 04.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioSettingsKit
import CoreAudio

public final class AudioDevicesProviderMock: AudioDevicesProviderType, @unchecked Sendable {
    public enum Calls: Equatable {
        case devices(AudioDeviceFilter)
        case device(AudioDeviceID)
    }

    public private(set) var calls: [Calls] = []
    public var devicesResult: [AudioDevice]
    public var deviceByID: [AudioDeviceID: AudioDevice]

    public init(
        devicesResult: [AudioDevice] = [],
        deviceByID: [AudioDeviceID: AudioDevice] = [:]
    ) {
        self.devicesResult = devicesResult
        self.deviceByID = deviceByID
    }

    public func devices(_ filter: AudioDeviceFilter) -> [AudioDevice] {
        calls.append(.devices(filter))
        return devicesResult
    }

    public func device(id: AudioDeviceID) -> AudioDevice? {
        calls.append(.device(id))
        return deviceByID[id]
    }
}
