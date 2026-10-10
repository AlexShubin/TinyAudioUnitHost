//
//  AudioDevicesProviderTests.swift
//  AudioSettingsKitTests
//
//  Created by Alex Shubin on 29.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import CoreAudioGatewayKit
import CoreAudioGatewayKitTestSupport
import Testing
@testable import AudioSettingsKit

@Suite
struct AudioDevicesProviderTests {
    var gatewaySpy: CoreAudioGatewaySpy!
    var sut: AudioDevicesProviderType!

    init() {
        gatewaySpy = CoreAudioGatewaySpy()
    }

    mutating func createSut() {
        sut = AudioDevicesProvider(gateway: gatewaySpy)
    }

    // MARK: - device(id:) resolution

    @Test
    mutating func deviceReturnsNilWhenUIDMissing() {
        gatewaySpy.deviceUIDResult = nil
        gatewaySpy.deviceNameResult = "Device"
        createSut()
        #expect(sut.device(id: 1) == nil)
    }

    @Test
    mutating func deviceReturnsNilWhenNameMissing() {
        gatewaySpy.deviceUIDResult = "uid"
        gatewaySpy.deviceNameResult = nil
        createSut()
        #expect(sut.device(id: 1) == nil)
    }

    @Test
    mutating func deviceResolvesUIDAndName() {
        gatewaySpy.deviceUIDResult = "uid-1"
        gatewaySpy.deviceNameResult = "Device One"
        createSut()
        let device = sut.device(id: 7)
        #expect(device?.id == 7)
        #expect(device?.uid == "uid-1")
        #expect(device?.name == "Device One")
    }

    // MARK: - channel resolution

    @Test
    mutating func deviceSumsChannelsPerFrameAcrossStreams() {
        gatewaySpy.deviceUIDResult = "uid"
        gatewaySpy.deviceNameResult = "Device"
        gatewaySpy.streamIDsResult = [10, 11] // two streams...
        gatewaySpy.channelsPerFrameResult = 2 // ...two channels each -> 4 total
        createSut()
        #expect(sut.device(id: 1)?.inputChannels == [
            AudioChannel(id: 1, name: "Channel 1"),
            AudioChannel(id: 2, name: "Channel 2"),
            AudioChannel(id: 3, name: "Channel 3"),
            AudioChannel(id: 4, name: "Channel 4")
        ])
    }

    @Test
    mutating func deviceUsesHardwareChannelNamesWhenAvailable() {
        gatewaySpy.deviceUIDResult = "uid"
        gatewaySpy.deviceNameResult = "Device"
        gatewaySpy.streamIDsResult = [10]
        gatewaySpy.channelsPerFrameResult = 2
        gatewaySpy.channelNameResult = "Mic In"
        createSut()
        #expect(sut.device(id: 1)?.inputChannels == [
            AudioChannel(id: 1, name: "Mic In"),
            AudioChannel(id: 2, name: "Mic In")
        ])
    }

    @Test
    mutating func deviceFallsBackToGenericChannelNameWhenHardwareHasNone() {
        gatewaySpy.deviceUIDResult = "uid"
        gatewaySpy.deviceNameResult = "Device"
        gatewaySpy.streamIDsResult = [10]
        gatewaySpy.channelsPerFrameResult = 2
        gatewaySpy.channelNameResult = nil
        createSut()
        #expect(sut.device(id: 1)?.inputChannels == [
            AudioChannel(id: 1, name: "Channel 1"),
            AudioChannel(id: 2, name: "Channel 2")
        ])
    }

    @Test
    mutating func deviceHasNoChannelsWhenStreamsAbsent() {
        gatewaySpy.deviceUIDResult = "uid"
        gatewaySpy.deviceNameResult = "Device"
        gatewaySpy.streamIDsResult = []
        createSut()
        let device = sut.device(id: 1)
        #expect(device?.inputChannels.isEmpty == true)
        #expect(device?.outputChannels.isEmpty == true)
    }

    // MARK: - buffer sizes

    @Test
    mutating func deviceFiltersBufferSizesToHardwareRange() {
        gatewaySpy.deviceUIDResult = "uid"
        gatewaySpy.deviceNameResult = "Device"
        gatewaySpy.bufferSizeRangeResult = 32...256
        createSut()
        #expect(sut.device(id: 1)?.availableBufferSizes == [32, 64, 128, 256])
    }

    @Test
    mutating func deviceReturnsNoBufferSizesWhenRangeMissing() {
        gatewaySpy.deviceUIDResult = "uid"
        gatewaySpy.deviceNameResult = "Device"
        gatewaySpy.bufferSizeRangeResult = nil
        createSut()
        #expect(sut.device(id: 1)?.availableBufferSizes == [])
    }

    // MARK: - sample rates

    @Test
    mutating func deviceFiltersSampleRatesToHardwareRanges() {
        gatewaySpy.deviceUIDResult = "uid"
        gatewaySpy.deviceNameResult = "Device"
        gatewaySpy.sampleRateRangesResult = [44_100...48_000]
        createSut()
        #expect(sut.device(id: 1)?.availableSampleRates == [44_100, 48_000])
    }

    @Test
    mutating func deviceReturnsNoSampleRatesWhenRangesMissing() {
        gatewaySpy.deviceUIDResult = "uid"
        gatewaySpy.deviceNameResult = "Device"
        gatewaySpy.sampleRateRangesResult = []
        createSut()
        #expect(sut.device(id: 1)?.availableSampleRates == [])
    }

    // MARK: - scanDevices

    @Test
    mutating func scanDevicesResolvesEveryID() async {
        gatewaySpy.allDeviceIDsResult = [1, 2]
        gatewaySpy.deviceUIDResult = "uid"
        gatewaySpy.deviceNameResult = "Device"
        createSut()
        #expect(await sut.scanDevices().map(\.id) == [1, 2])
    }

    @Test
    mutating func scanDevicesSkipsUnresolvableDevices() async {
        gatewaySpy.allDeviceIDsResult = [1, 2]
        gatewaySpy.deviceUIDResult = nil
        gatewaySpy.deviceNameResult = "Device"
        createSut()
        #expect(await sut.scanDevices().isEmpty)
    }
}
