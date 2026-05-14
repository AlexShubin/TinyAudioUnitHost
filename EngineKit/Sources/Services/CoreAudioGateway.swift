//
//  CoreAudioGateway.swift
//  EngineKit
//
//  Created by Alex Shubin on 30.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AVFoundation
import CoreAudio

protocol CoreAudioGatewayType {
    func setEnableIO(_ enabled: Bool, scope: AudioUnitScope, element: AudioUnitElement, on audioUnit: AudioUnit) throws
    func setCurrentDevice(_ deviceID: AudioDeviceID, on audioUnit: AudioUnit) throws
    func setChannelMap(_ map: [Int32], element: AudioUnitElement, on audioUnit: AudioUnit) throws
    func physicalChannelCount(of audioUnit: AudioUnit) -> Int?
    func setBufferSize(_ frames: UInt32, deviceID: AudioDeviceID) throws
    func setSampleRate(_ rate: Float64, deviceID: AudioDeviceID) throws
}

struct CoreAudioGatewayError: Error, Sendable, Equatable {
    enum Operation: Sendable, Equatable {
        case setEnableIO
        case setCurrentDevice
        case setChannelMap
        case setBufferSize
        case setSampleRate
    }

    let operation: Operation
    let status: Int32
}

struct CoreAudioGateway: CoreAudioGatewayType {
    func setEnableIO(_ enabled: Bool, scope: AudioUnitScope, element: AudioUnitElement, on audioUnit: AudioUnit) throws {
        var flag: UInt32 = enabled ? 1 : 0
        let status = AudioUnitSetProperty(
            audioUnit,
            kAudioOutputUnitProperty_EnableIO,
            scope,
            element,
            &flag,
            UInt32(MemoryLayout<UInt32>.size)
        )
        try check(status, operation: .setEnableIO)
    }

    func setCurrentDevice(_ deviceID: AudioDeviceID, on audioUnit: AudioUnit) throws {
        var id = deviceID
        let size = UInt32(MemoryLayout<UInt32>.size)
        let status = AudioUnitSetProperty(
            audioUnit,
            kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global,
            0,
            &id,
            size
        )
        try check(status, operation: .setCurrentDevice)
    }

    func setChannelMap(_ map: [Int32], element: AudioUnitElement, on audioUnit: AudioUnit) throws {
        var mutableMap = map
        let size = UInt32(MemoryLayout<Int32>.size * mutableMap.count)
        let status = AudioUnitSetProperty(
            audioUnit,
            kAudioOutputUnitProperty_ChannelMap,
            kAudioUnitScope_Output,
            element, // 1 input bus, 0 output bus
            &mutableMap,
            size
        )
        try check(status, operation: .setChannelMap)
    }

    func physicalChannelCount(of audioUnit: AudioUnit) -> Int? {
        var streamFormat = AudioStreamBasicDescription()
        var size = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        let status = AudioUnitGetProperty(
            audioUnit,
            kAudioUnitProperty_StreamFormat,
            kAudioUnitScope_Output,
            0,
            &streamFormat,
            &size
        )
        guard status == noErr else { return nil }
        return Int(streamFormat.mChannelsPerFrame)
    }

    func setBufferSize(_ frames: UInt32, deviceID: AudioDeviceID) throws {
        var size = frames
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyBufferFrameSize,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = AudioObjectSetPropertyData(
            deviceID,
            &address,
            0,
            nil,
            UInt32(MemoryLayout<UInt32>.size),
            &size
        )
        try check(status, operation: .setBufferSize)
    }

    func setSampleRate(_ rate: Float64, deviceID: AudioDeviceID) throws {
        var rate = rate
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyNominalSampleRate,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = AudioObjectSetPropertyData(
            deviceID,
            &address,
            0,
            nil,
            UInt32(MemoryLayout<Float64>.size),
            &rate
        )
        try check(status, operation: .setSampleRate)
    }

    private func check(_ status: OSStatus, operation: CoreAudioGatewayError.Operation) throws {
        guard status == noErr else {
            throw CoreAudioGatewayError(operation: operation, status: status)
        }
    }
}
