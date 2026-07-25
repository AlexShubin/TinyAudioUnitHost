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

    var setEnableIOError: CoreAudioGatewayError?
    func setEnableIO(_ enabled: Bool, scope: AudioUnitScope, element: AudioUnitElement, on audioUnit: AudioUnit) throws(CoreAudioGatewayError) {
        calls.append(.setEnableIO(enabled, scope, element, audioUnit))
        if let setEnableIOError { throw setEnableIOError }
    }

    var setCurrentDeviceError: CoreAudioGatewayError?
    func setCurrentDevice(_ deviceID: AudioDeviceID, on audioUnit: AudioUnit) throws(CoreAudioGatewayError) {
        calls.append(.setCurrentDevice(deviceID, audioUnit))
        if let setCurrentDeviceError { throw setCurrentDeviceError }
    }

    var setChannelMapError: CoreAudioGatewayError?
    func setChannelMap(_ map: [Int32], element: AudioUnitElement, on audioUnit: AudioUnit) throws(CoreAudioGatewayError) {
        calls.append(.setChannelMap(map, element, audioUnit))
        if let setChannelMapError { throw setChannelMapError }
    }

    var physicalChannelCountResult: Int?
    func physicalChannelCount(of audioUnit: AudioUnit) -> Int? {
        calls.append(.physicalChannelCount(audioUnit))
        return physicalChannelCountResult
    }

    var setBufferSizeError: CoreAudioGatewayError?
    func setBufferSize(_ frames: UInt32, deviceID: AudioDeviceID) throws(CoreAudioGatewayError) {
        calls.append(.setBufferSize(frames, deviceID))
        if let setBufferSizeError { throw setBufferSizeError }
    }

    var setSampleRateError: CoreAudioGatewayError?
    func setSampleRate(_ rate: Float64, deviceID: AudioDeviceID) throws(CoreAudioGatewayError) {
        calls.append(.setSampleRate(rate, deviceID))
        if let setSampleRateError { throw setSampleRateError }
    }
}
