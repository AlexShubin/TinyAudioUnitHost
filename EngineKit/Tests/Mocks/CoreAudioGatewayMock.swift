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

final class CoreAudioGatewayMock: CoreAudioGatewayType, @unchecked Sendable {
    enum Calls: Equatable {
        case setEnableIO(Bool, AudioUnitScope, AudioUnitElement, AudioUnit)
        case setCurrentDevice(AudioDeviceID, AudioUnit)
        case setChannelMap([Int32], AudioUnitElement, AudioUnit)
        case physicalChannelCount(AudioUnit)
        case setBufferSize(UInt32, AudioDeviceID)
        case setSampleRate(Float64, AudioDeviceID)
    }

    private(set) var calls: [Calls] = []
    var physicalChannelCountResult: Int?
    var setEnableIOError: Error?
    var setCurrentDeviceError: Error?
    var setChannelMapError: Error?
    var setBufferSizeError: Error?
    var setSampleRateError: Error?

    init(
        physicalChannelCountResult: Int? = nil,
        setEnableIOError: Error? = nil,
        setCurrentDeviceError: Error? = nil,
        setChannelMapError: Error? = nil,
        setBufferSizeError: Error? = nil,
        setSampleRateError: Error? = nil
    ) {
        self.physicalChannelCountResult = physicalChannelCountResult
        self.setEnableIOError = setEnableIOError
        self.setCurrentDeviceError = setCurrentDeviceError
        self.setChannelMapError = setChannelMapError
        self.setBufferSizeError = setBufferSizeError
        self.setSampleRateError = setSampleRateError
    }

    func setEnableIO(_ enabled: Bool, scope: AudioUnitScope, element: AudioUnitElement, on audioUnit: AudioUnit) throws {
        calls.append(.setEnableIO(enabled, scope, element, audioUnit))
        if let setEnableIOError { throw setEnableIOError }
    }

    func setCurrentDevice(_ deviceID: AudioDeviceID, on audioUnit: AudioUnit) throws {
        calls.append(.setCurrentDevice(deviceID, audioUnit))
        if let setCurrentDeviceError { throw setCurrentDeviceError }
    }

    func setChannelMap(_ map: [Int32], element: AudioUnitElement, on audioUnit: AudioUnit) throws {
        calls.append(.setChannelMap(map, element, audioUnit))
        if let setChannelMapError { throw setChannelMapError }
    }

    func physicalChannelCount(of audioUnit: AudioUnit) -> Int? {
        calls.append(.physicalChannelCount(audioUnit))
        return physicalChannelCountResult
    }

    func setBufferSize(_ frames: UInt32, deviceID: AudioDeviceID) throws {
        calls.append(.setBufferSize(frames, deviceID))
        if let setBufferSizeError { throw setBufferSizeError }
    }

    func setSampleRate(_ rate: Float64, deviceID: AudioDeviceID) throws {
        calls.append(.setSampleRate(rate, deviceID))
        if let setSampleRateError { throw setSampleRateError }
    }
}
