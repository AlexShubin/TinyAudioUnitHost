//
//  AudioUnitGatewaySpy.swift
//  EngineKitTests
//
//  Created by Alex Shubin on 30.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AVFoundation
import CoreAudio
@testable import EngineKit

final class AudioUnitGatewaySpy: AudioUnitGatewayType, @unchecked Sendable {
    enum Calls: Equatable {
        case setEnableIO(Bool, AudioUnitScope, AudioUnitElement, AudioUnit)
        case setCurrentDevice(AudioDeviceID, AudioUnit)
        case setChannelMap([Int32], AudioUnitElement, AudioUnit)
        case physicalChannelCount(AudioUnit)
    }

    private(set) var calls: [Calls] = []

    var setEnableIOError: AudioUnitGatewayError?
    func setEnableIO(_ enabled: Bool, scope: AudioUnitScope, element: AudioUnitElement, on audioUnit: AudioUnit) throws(AudioUnitGatewayError) {
        calls.append(.setEnableIO(enabled, scope, element, audioUnit))
        if let setEnableIOError { throw setEnableIOError }
    }

    var setCurrentDeviceError: AudioUnitGatewayError?
    func setCurrentDevice(_ deviceID: AudioDeviceID, on audioUnit: AudioUnit) throws(AudioUnitGatewayError) {
        calls.append(.setCurrentDevice(deviceID, audioUnit))
        if let setCurrentDeviceError { throw setCurrentDeviceError }
    }

    var setChannelMapError: AudioUnitGatewayError?
    func setChannelMap(_ map: [Int32], element: AudioUnitElement, on audioUnit: AudioUnit) throws(AudioUnitGatewayError) {
        calls.append(.setChannelMap(map, element, audioUnit))
        if let setChannelMapError { throw setChannelMapError }
    }

    var physicalChannelCountResult: Int?
    func physicalChannelCount(of audioUnit: AudioUnit) -> Int? {
        calls.append(.physicalChannelCount(audioUnit))
        return physicalChannelCountResult
    }
}
