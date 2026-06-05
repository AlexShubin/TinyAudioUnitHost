//
//  CoreAudioGateway.swift
//  AudioSettingsKit
//
//  Created by Alex Shubin on 29.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import CoreAudio

protocol CoreAudioGatewayType: Sendable {
    var allDeviceIDs: [UInt32] { get }
    func deviceUID(of deviceID: UInt32) -> String?
    func deviceName(of deviceID: UInt32) -> String?
    func streamIDs(of deviceID: UInt32, scope: AudioDeviceScope) -> [UInt32]
    func channelsPerFrame(of streamID: UInt32) -> Int
    func channelName(of deviceID: UInt32, scope: AudioDeviceScope, channel: UInt32) -> String?
    func bufferSizeRange(of deviceID: UInt32) -> ClosedRange<Double>?
    func sampleRateRanges(of deviceID: UInt32) -> [ClosedRange<Double>]
    func createAggregateDevice(
        name: String,
        uid: String,
        isPrivate: Bool,
        isStacked: Bool,
        mainSubDeviceUID: String,
        subDeviceUIDs: [String]
    ) -> UInt32?
    func destroyAggregateDevice(id: UInt32)
}

enum AudioDeviceScope: Sendable, Equatable {
    case input
    case output
}

struct CoreAudioGateway: CoreAudioGatewayType {
    var allDeviceIDs: [UInt32] {
        AudioObjectID(kAudioObjectSystemObject).getArray(selector: kAudioHardwarePropertyDevices)
    }

    func deviceUID(of deviceID: UInt32) -> String? {
        deviceID.getString(selector: kAudioDevicePropertyDeviceUID)
    }

    func deviceName(of deviceID: UInt32) -> String? {
        deviceID.getString(selector: kAudioObjectPropertyName)
    }

    func streamIDs(of deviceID: UInt32, scope: AudioDeviceScope) -> [UInt32] {
        deviceID.getArray(selector: kAudioDevicePropertyStreams, scope: scope.propertyScope)
    }

    func channelsPerFrame(of streamID: UInt32) -> Int {
        let format: AudioStreamBasicDescription? = streamID.getProperty(
            selector: kAudioStreamPropertyPhysicalFormat,
            defaultValue: AudioStreamBasicDescription()
        )
        return Int(format?.mChannelsPerFrame ?? 0)
    }

    func channelName(of deviceID: UInt32, scope: AudioDeviceScope, channel: UInt32) -> String? {
        deviceID.getString(
            selector: kAudioObjectPropertyElementName,
            scope: scope.propertyScope,
            element: channel
        )
    }

    func bufferSizeRange(of deviceID: UInt32) -> ClosedRange<Double>? {
        guard let range: AudioValueRange = deviceID.getProperty(
            selector: kAudioDevicePropertyBufferFrameSizeRange,
            defaultValue: AudioValueRange()
        ) else { return nil }
        return range.mMinimum...range.mMaximum
    }

    func sampleRateRanges(of deviceID: UInt32) -> [ClosedRange<Double>] {
        let ranges: [AudioValueRange] = deviceID.getArray(
            selector: kAudioDevicePropertyAvailableNominalSampleRates
        )
        return ranges.map { $0.mMinimum...$0.mMaximum }
    }

    func createAggregateDevice(
        name: String,
        uid: String,
        isPrivate: Bool,
        isStacked: Bool,
        mainSubDeviceUID: String,
        subDeviceUIDs: [String]
    ) -> UInt32? {
        let description: [String: Any] = [
            kAudioAggregateDeviceNameKey as String: name,
            kAudioAggregateDeviceUIDKey as String: uid,
            kAudioAggregateDeviceIsPrivateKey as String: isPrivate ? 1 : 0,
            kAudioAggregateDeviceIsStackedKey as String: isStacked ? 1 : 0,
            kAudioAggregateDeviceMainSubDeviceKey as String: mainSubDeviceUID,
            kAudioAggregateDeviceSubDeviceListKey as String: subDeviceUIDs.map {
                [kAudioSubDeviceUIDKey as String: $0]
            }
        ]
        var aggregateID: AudioDeviceID = 0
        let status = AudioHardwareCreateAggregateDevice(description as CFDictionary, &aggregateID)
        return status == noErr ? aggregateID : nil
    }

    func destroyAggregateDevice(id: UInt32) {
        AudioHardwareDestroyAggregateDevice(id)
    }
}

private extension AudioDeviceScope {
    var propertyScope: AudioObjectPropertyScope {
        switch self {
        case .input: kAudioDevicePropertyScopeInput
        case .output: kAudioDevicePropertyScopeOutput
        }
    }
}

private extension AudioObjectID {
    func getProperty<T: BitwiseCopyable>(
        selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal,
        element: AudioObjectPropertyElement = kAudioObjectPropertyElementMain,
        defaultValue: T
    ) -> T? {
        var address = AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: element)
        var value = defaultValue
        var size = UInt32(MemoryLayout<T>.size)
        let status = AudioObjectGetPropertyData(self, &address, 0, nil, &size, &value)
        return status == noErr ? value : nil
    }

    func getString(
        selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal,
        element: AudioObjectPropertyElement = kAudioObjectPropertyElementMain
    ) -> String? {
        var address = AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: element)
        var result: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(self, &address, 0, nil, &size, &result) == noErr,
              let result
        else { return nil }
        let string = result.takeRetainedValue() as String
        return string.isEmpty ? nil : string
    }

    func getArray<T: BitwiseCopyable>(
        selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal,
        element: AudioObjectPropertyElement = kAudioObjectPropertyElementMain
    ) -> [T] {
        var address = AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: element)
        var dataSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(self, &address, 0, nil, &dataSize) == noErr
        else { return [] }
        let count = Int(dataSize) / MemoryLayout<T>.stride
        guard count > 0 else { return [] }
        return [T](unsafeUninitializedCapacity: count) { buffer, initialized in
            var size = dataSize
            let status = AudioObjectGetPropertyData(self, &address, 0, nil, &size, buffer.baseAddress!)
            initialized = status == noErr ? count : 0
        }
    }
}
