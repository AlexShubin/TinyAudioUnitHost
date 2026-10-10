//
//  CoreAudioGatewaySpy.swift
//  CoreAudioGatewayKitTestSupport
//
//  Created by Alex Shubin on 10.10.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import Common
import CoreAudioGatewayKit

public final class CoreAudioGatewaySpy: CoreAudioGatewayType, @unchecked Sendable {
    public enum Calls: Equatable {
        case allDeviceIDs
        case deviceUID(UInt32)
        case deviceName(UInt32)
        case streamIDs(UInt32, AudioDeviceScope)
        case channelsPerFrame(UInt32)
        case channelName(deviceID: UInt32, scope: AudioDeviceScope, channel: UInt32)
        case bufferSizeRange(UInt32)
        case sampleRateRanges(UInt32)
        case createAggregateDevice(
            name: String,
            uid: String,
            isPrivate: Bool,
            isStacked: Bool,
            mainSubDeviceUID: String,
            subDeviceUIDs: [String]
        )
        case destroyAggregateDevice(UInt32)
        case setBufferSize(UInt32, UInt32)
        case setSampleRate(Float64, UInt32)
        case observeDeviceListChanges
    }

    public private(set) var calls: [Calls] = []

    public init() {}

    public var allDeviceIDsResult: [UInt32] = []
    public var allDeviceIDs: [UInt32] {
        calls.append(.allDeviceIDs)
        return allDeviceIDsResult
    }

    public var deviceUIDResult: String?
    public func deviceUID(of deviceID: UInt32) -> String? {
        calls.append(.deviceUID(deviceID))
        return deviceUIDResult
    }

    public var deviceNameResult: String?
    public func deviceName(of deviceID: UInt32) -> String? {
        calls.append(.deviceName(deviceID))
        return deviceNameResult
    }

    public var streamIDsResult: [UInt32] = []
    public func streamIDs(of deviceID: UInt32, scope: AudioDeviceScope) -> [UInt32] {
        calls.append(.streamIDs(deviceID, scope))
        return streamIDsResult
    }

    public var channelsPerFrameResult = 0
    public func channelsPerFrame(of streamID: UInt32) -> Int {
        calls.append(.channelsPerFrame(streamID))
        return channelsPerFrameResult
    }

    public var channelNameResult: String?
    public func channelName(of deviceID: UInt32, scope: AudioDeviceScope, channel: UInt32) -> String? {
        calls.append(.channelName(deviceID: deviceID, scope: scope, channel: channel))
        return channelNameResult
    }

    public var bufferSizeRangeResult: ClosedRange<Double>?
    public func bufferSizeRange(of deviceID: UInt32) -> ClosedRange<Double>? {
        calls.append(.bufferSizeRange(deviceID))
        return bufferSizeRangeResult
    }

    public var sampleRateRangesResult: [ClosedRange<Double>] = []
    public func sampleRateRanges(of deviceID: UInt32) -> [ClosedRange<Double>] {
        calls.append(.sampleRateRanges(deviceID))
        return sampleRateRangesResult
    }

    public var createAggregateDeviceResult: UInt32?
    public func createAggregateDevice(
        name: String,
        uid: String,
        isPrivate: Bool,
        isStacked: Bool,
        mainSubDeviceUID: String,
        subDeviceUIDs: [String]
    ) -> UInt32? {
        calls.append(.createAggregateDevice(
            name: name,
            uid: uid,
            isPrivate: isPrivate,
            isStacked: isStacked,
            mainSubDeviceUID: mainSubDeviceUID,
            subDeviceUIDs: subDeviceUIDs
        ))
        return createAggregateDeviceResult
    }

    public func destroyAggregateDevice(id: UInt32) {
        calls.append(.destroyAggregateDevice(id))
    }

    public var setBufferSizeError: CoreAudioGatewayError?
    public func setBufferSize(_ frames: UInt32, deviceID: UInt32) throws(CoreAudioGatewayError) {
        calls.append(.setBufferSize(frames, deviceID))
        if let setBufferSizeError { throw setBufferSizeError }
    }

    public var setSampleRateError: CoreAudioGatewayError?
    public func setSampleRate(_ rate: Float64, deviceID: UInt32) throws(CoreAudioGatewayError) {
        calls.append(.setSampleRate(rate, deviceID))
        if let setSampleRateError { throw setSampleRateError }
    }

    public private(set) var deviceListChangeHandler: (@Sendable () async -> Void)?
    public func observeDeviceListChanges(_ handler: @escaping @Sendable () async -> Void) -> Cancellation {
        deviceListChangeHandler = handler
        calls.append(.observeDeviceListChanges)
        return Cancellation {}
    }
}
