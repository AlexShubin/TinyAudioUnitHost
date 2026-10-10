//
//  AudioUnitGateway.swift
//  AudioToolboxGatewayKit
//
//  Created by Alex Shubin on 30.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioToolbox

public protocol AudioUnitGatewayType: Sendable {
    func setEnableIO(_ enabled: Bool, bus: AudioUnitBus, on audioUnit: AudioUnit) throws(AudioUnitGatewayError)
    func setCurrentDevice(_ deviceID: UInt32, on audioUnit: AudioUnit) throws(AudioUnitGatewayError)
    func setChannelMap(_ map: [Int32], bus: AudioUnitBus, on audioUnit: AudioUnit) throws(AudioUnitGatewayError)
    func physicalChannelCount(of audioUnit: AudioUnit) -> Int?
}

public enum AudioUnitBus: Sendable, Equatable {
    case input
    case output
}

public struct AudioUnitGatewayError: Error, Sendable, Equatable {
    public enum Operation: Sendable, Equatable {
        case setEnableIO
        case setCurrentDevice
        case setChannelMap
    }

    public let operation: Operation
    public let status: Int32

    public init(operation: Operation, status: Int32) {
        self.operation = operation
        self.status = status
    }
}

struct AudioUnitGateway: AudioUnitGatewayType {
    func setEnableIO(_ enabled: Bool, bus: AudioUnitBus, on audioUnit: AudioUnit) throws(AudioUnitGatewayError) {
        var flag: UInt32 = enabled ? 1 : 0
        let status = AudioUnitSetProperty(
            audioUnit,
            kAudioOutputUnitProperty_EnableIO,
            bus.scope,
            bus.element,
            &flag,
            UInt32(MemoryLayout<UInt32>.size)
        )
        try check(status, operation: .setEnableIO)
    }

    func setCurrentDevice(_ deviceID: UInt32, on audioUnit: AudioUnit) throws(AudioUnitGatewayError) {
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

    func setChannelMap(_ map: [Int32], bus: AudioUnitBus, on audioUnit: AudioUnit) throws(AudioUnitGatewayError) {
        var mutableMap = map
        let size = UInt32(MemoryLayout<Int32>.size * mutableMap.count)
        let status = AudioUnitSetProperty(
            audioUnit,
            kAudioOutputUnitProperty_ChannelMap,
            kAudioUnitScope_Output,
            bus.element,
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

    private func check(_ status: OSStatus, operation: AudioUnitGatewayError.Operation) throws(AudioUnitGatewayError) {
        guard status == noErr else {
            throw AudioUnitGatewayError(operation: operation, status: status)
        }
    }
}

private extension AudioUnitBus {
    var scope: AudioUnitScope {
        switch self {
        case .input: kAudioUnitScope_Input
        case .output: kAudioUnitScope_Output
        }
    }

    var element: AudioUnitElement {
        switch self {
        case .input: 1
        case .output: 0
        }
    }
}
