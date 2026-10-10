//
//  AudioUnitGatewaySpy.swift
//  AudioToolboxGatewayKitTestSupport
//
//  Created by Alex Shubin on 30.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioToolbox
import AudioToolboxGatewayKit
import CoreAudio

public final class AudioUnitGatewaySpy: AudioUnitGatewayType, @unchecked Sendable {
    public enum Calls: Equatable {
        case setEnableIO(Bool, AudioUnitScope, AudioUnitElement, AudioUnit)
        case setCurrentDevice(AudioDeviceID, AudioUnit)
        case setChannelMap([Int32], AudioUnitElement, AudioUnit)
        case physicalChannelCount(AudioUnit)
    }

    public private(set) var calls: [Calls] = []

    public init() {}

    public var setEnableIOError: AudioUnitGatewayError?
    public func setEnableIO(_ enabled: Bool, scope: AudioUnitScope, element: AudioUnitElement, on audioUnit: AudioUnit) throws(AudioUnitGatewayError) {
        calls.append(.setEnableIO(enabled, scope, element, audioUnit))
        if let setEnableIOError { throw setEnableIOError }
    }

    public var setCurrentDeviceError: AudioUnitGatewayError?
    public func setCurrentDevice(_ deviceID: AudioDeviceID, on audioUnit: AudioUnit) throws(AudioUnitGatewayError) {
        calls.append(.setCurrentDevice(deviceID, audioUnit))
        if let setCurrentDeviceError { throw setCurrentDeviceError }
    }

    public var setChannelMapError: AudioUnitGatewayError?
    public func setChannelMap(_ map: [Int32], element: AudioUnitElement, on audioUnit: AudioUnit) throws(AudioUnitGatewayError) {
        calls.append(.setChannelMap(map, element, audioUnit))
        if let setChannelMapError { throw setChannelMapError }
    }

    public var physicalChannelCountResult: Int?
    public func physicalChannelCount(of audioUnit: AudioUnit) -> Int? {
        calls.append(.physicalChannelCount(audioUnit))
        return physicalChannelCountResult
    }
}
