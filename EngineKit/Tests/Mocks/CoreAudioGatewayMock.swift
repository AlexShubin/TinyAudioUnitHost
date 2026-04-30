//
//  CoreAudioGatewayMock.swift
//  EngineKitTests
//
//  Created by Alex Shubin on 30.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AVFoundation
import CoreAudio
@testable import EngineKit

final class CoreAudioGatewayMock: CoreAudioGatewayType {
    enum Calls: Equatable {
        case setEnableIO(Bool, AudioUnitScope, AudioUnitElement, AudioUnit)
        case setCurrentDevice(AudioDeviceID, AudioUnit)
        case setChannelMap([Int32], AudioUnitElement, AudioUnit)
        case physicalChannelCount(AudioUnit)
        case setBufferSize(UInt32, AudioDeviceID)
    }

    private(set) var calls: [Calls] = []
    var physicalChannelCountResult: Int?

    init(physicalChannelCountResult: Int? = nil) {
        self.physicalChannelCountResult = physicalChannelCountResult
    }

    func setEnableIO(_ enabled: Bool, scope: AudioUnitScope, element: AudioUnitElement, on audioUnit: AudioUnit) {
        calls.append(.setEnableIO(enabled, scope, element, audioUnit))
    }

    func setCurrentDevice(_ deviceID: AudioDeviceID, on audioUnit: AudioUnit) {
        calls.append(.setCurrentDevice(deviceID, audioUnit))
    }

    func setChannelMap(_ map: [Int32], element: AudioUnitElement, on audioUnit: AudioUnit) {
        calls.append(.setChannelMap(map, element, audioUnit))
    }

    func physicalChannelCount(of audioUnit: AudioUnit) -> Int? {
        calls.append(.physicalChannelCount(audioUnit))
        return physicalChannelCountResult
    }

    func setBufferSize(_ frames: UInt32, deviceID: AudioDeviceID) {
        calls.append(.setBufferSize(frames, deviceID))
    }
}
