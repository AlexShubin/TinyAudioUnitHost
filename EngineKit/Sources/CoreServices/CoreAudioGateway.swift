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
    func setEnableIO(_ enabled: Bool, scope: AudioUnitScope, element: AudioUnitElement, on audioUnit: AudioUnit)
    func setCurrentDevice(_ deviceID: AudioDeviceID, on audioUnit: AudioUnit)
    func setChannelMap(_ map: [Int32], element: AudioUnitElement, on audioUnit: AudioUnit)
    func physicalChannelCount(of audioUnit: AudioUnit) -> Int?
    func setBufferSize(_ frames: UInt32, deviceID: AudioDeviceID)
    func setSampleRate(_ rate: Float64, deviceID: AudioDeviceID)
}

struct CoreAudioGateway: CoreAudioGatewayType {
    func setEnableIO(_ enabled: Bool, scope: AudioUnitScope, element: AudioUnitElement, on audioUnit: AudioUnit) {
        var flag: UInt32 = enabled ? 1 : 0
        let status = AudioUnitSetProperty(
            audioUnit,
            kAudioOutputUnitProperty_EnableIO,
            scope,
            element,
            &flag,
            UInt32(MemoryLayout<UInt32>.size)
        )
        assert(status == noErr, "Failed to set EnableIO: \(status)")
    }

    func setCurrentDevice(_ deviceID: AudioDeviceID, on audioUnit: AudioUnit) {
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
        assert(status == noErr, "Failed to set current device: \(status)")
    }

    func setChannelMap(_ map: [Int32], element: AudioUnitElement, on audioUnit: AudioUnit) {
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
        assert(status == noErr, "Failed to set channel map: \(status)")
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

    func setBufferSize(_ frames: UInt32, deviceID: AudioDeviceID) {
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
        assert(status == noErr, "Failed to set buffer size: \(status)")
    }

    func setSampleRate(_ rate: Float64, deviceID: AudioDeviceID) {
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
        assert(status == noErr, "Failed to set sample rate: \(status)")
    }
}
