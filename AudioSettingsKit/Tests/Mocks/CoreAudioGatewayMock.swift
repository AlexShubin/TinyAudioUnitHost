//
//  CoreAudioGatewayMock.swift
//  AudioSettingsKitTests
//
//  Created by Alex Shubin on 29.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

@testable import AudioSettingsKit

final class CoreAudioGatewayMock: CoreAudioGatewayType, @unchecked Sendable {
    enum Calls: Equatable {
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
    }

    private(set) var calls: [Calls] = []
    var allDeviceIDsResult: [UInt32]
    var deviceUIDResult: String?
    var deviceNameResult: String?
    var streamIDsResult: [UInt32]
    var channelsPerFrameResult: Int
    var channelNameResult: String?
    var bufferSizeRangeResult: ClosedRange<Double>?
    var sampleRateRangesResult: [ClosedRange<Double>]
    var createAggregateDeviceResult: UInt32?

    init(
        allDeviceIDsResult: [UInt32] = [],
        deviceUIDResult: String? = nil,
        deviceNameResult: String? = nil,
        streamIDsResult: [UInt32] = [],
        channelsPerFrameResult: Int = 0,
        channelNameResult: String? = nil,
        bufferSizeRangeResult: ClosedRange<Double>? = nil,
        sampleRateRangesResult: [ClosedRange<Double>] = [],
        createAggregateDeviceResult: UInt32? = nil
    ) {
        self.allDeviceIDsResult = allDeviceIDsResult
        self.deviceUIDResult = deviceUIDResult
        self.deviceNameResult = deviceNameResult
        self.streamIDsResult = streamIDsResult
        self.channelsPerFrameResult = channelsPerFrameResult
        self.channelNameResult = channelNameResult
        self.bufferSizeRangeResult = bufferSizeRangeResult
        self.sampleRateRangesResult = sampleRateRangesResult
        self.createAggregateDeviceResult = createAggregateDeviceResult
    }

    var allDeviceIDs: [UInt32] {
        calls.append(.allDeviceIDs)
        return allDeviceIDsResult
    }

    func deviceUID(of deviceID: UInt32) -> String? {
        calls.append(.deviceUID(deviceID))
        return deviceUIDResult
    }

    func deviceName(of deviceID: UInt32) -> String? {
        calls.append(.deviceName(deviceID))
        return deviceNameResult
    }

    func streamIDs(of deviceID: UInt32, scope: AudioDeviceScope) -> [UInt32] {
        calls.append(.streamIDs(deviceID, scope))
        return streamIDsResult
    }

    func channelsPerFrame(of streamID: UInt32) -> Int {
        calls.append(.channelsPerFrame(streamID))
        return channelsPerFrameResult
    }

    func channelName(of deviceID: UInt32, scope: AudioDeviceScope, channel: UInt32) -> String? {
        calls.append(.channelName(deviceID: deviceID, scope: scope, channel: channel))
        return channelNameResult
    }

    func bufferSizeRange(of deviceID: UInt32) -> ClosedRange<Double>? {
        calls.append(.bufferSizeRange(deviceID))
        return bufferSizeRangeResult
    }

    func sampleRateRanges(of deviceID: UInt32) -> [ClosedRange<Double>] {
        calls.append(.sampleRateRanges(deviceID))
        return sampleRateRangesResult
    }

    func createAggregateDevice(
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

    func destroyAggregateDevice(id: UInt32) {
        calls.append(.destroyAggregateDevice(id))
    }
}
