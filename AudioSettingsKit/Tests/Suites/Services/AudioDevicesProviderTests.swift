//
//  AudioDevicesProviderTests.swift
//  AudioSettingsKitTests
//
//  Created by Alex Shubin on 29.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import Testing
@testable import AudioSettingsKit

@Suite
struct AudioDevicesProviderTests {
    var gatewayMock: CoreAudioGatewayMock!
    var sut: AudioDevicesProviderType!

    init() {
        gatewayMock = CoreAudioGatewayMock()
    }

    mutating func createSut() {
        sut = AudioDevicesProvider(gateway: gatewayMock)
    }

    // MARK: - device(id:) resolution

    @Test
    mutating func deviceReturnsNilWhenUIDMissing() {
        gatewayMock.deviceUIDResult = nil
        gatewayMock.deviceNameResult = "Device"
        createSut()
        #expect(sut.device(id: 1) == nil)
    }

    @Test
    mutating func deviceReturnsNilWhenNameMissing() {
        gatewayMock.deviceUIDResult = "uid"
        gatewayMock.deviceNameResult = nil
        createSut()
        #expect(sut.device(id: 1) == nil)
    }

    @Test
    mutating func deviceResolvesUIDAndName() {
        gatewayMock.deviceUIDResult = "uid-1"
        gatewayMock.deviceNameResult = "Device One"
        createSut()
        let device = sut.device(id: 7)
        #expect(device?.id == 7)
        #expect(device?.uid == "uid-1")
        #expect(device?.name == "Device One")
    }

    // MARK: - channel resolution

    @Test
    mutating func deviceSumsChannelsPerFrameAcrossStreams() {
        gatewayMock.deviceUIDResult = "uid"
        gatewayMock.deviceNameResult = "Device"
        gatewayMock.streamIDsResult = [10, 11] // two streams...
        gatewayMock.channelsPerFrameResult = 2 // ...two channels each -> 4 total
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
        gatewayMock.deviceUIDResult = "uid"
        gatewayMock.deviceNameResult = "Device"
        gatewayMock.streamIDsResult = [10]
        gatewayMock.channelsPerFrameResult = 2
        gatewayMock.channelNameResult = "Mic In"
        createSut()
        #expect(sut.device(id: 1)?.inputChannels == [
            AudioChannel(id: 1, name: "Mic In"),
            AudioChannel(id: 2, name: "Mic In")
        ])
    }

    @Test
    mutating func deviceFallsBackToGenericChannelNameWhenHardwareHasNone() {
        gatewayMock.deviceUIDResult = "uid"
        gatewayMock.deviceNameResult = "Device"
        gatewayMock.streamIDsResult = [10]
        gatewayMock.channelsPerFrameResult = 2
        gatewayMock.channelNameResult = nil
        createSut()
        #expect(sut.device(id: 1)?.inputChannels == [
            AudioChannel(id: 1, name: "Channel 1"),
            AudioChannel(id: 2, name: "Channel 2")
        ])
    }

    @Test
    mutating func deviceHasNoChannelsWhenStreamsAbsent() {
        gatewayMock.deviceUIDResult = "uid"
        gatewayMock.deviceNameResult = "Device"
        gatewayMock.streamIDsResult = []
        createSut()
        let device = sut.device(id: 1)
        #expect(device?.inputChannels.isEmpty == true)
        #expect(device?.outputChannels.isEmpty == true)
    }

    // MARK: - buffer sizes

    @Test
    mutating func deviceFiltersBufferSizesToHardwareRange() {
        gatewayMock.deviceUIDResult = "uid"
        gatewayMock.deviceNameResult = "Device"
        gatewayMock.bufferSizeRangeResult = 32...256
        createSut()
        #expect(sut.device(id: 1)?.availableBufferSizes == [32, 64, 128, 256])
    }

    @Test
    mutating func deviceReturnsNoBufferSizesWhenRangeMissing() {
        gatewayMock.deviceUIDResult = "uid"
        gatewayMock.deviceNameResult = "Device"
        gatewayMock.bufferSizeRangeResult = nil
        createSut()
        #expect(sut.device(id: 1)?.availableBufferSizes == [])
    }

    // MARK: - sample rates

    @Test
    mutating func deviceFiltersSampleRatesToHardwareRanges() {
        gatewayMock.deviceUIDResult = "uid"
        gatewayMock.deviceNameResult = "Device"
        gatewayMock.sampleRateRangesResult = [44_100...48_000]
        createSut()
        #expect(sut.device(id: 1)?.availableSampleRates == [44_100, 48_000])
    }

    @Test
    mutating func deviceReturnsNoSampleRatesWhenRangesMissing() {
        gatewayMock.deviceUIDResult = "uid"
        gatewayMock.deviceNameResult = "Device"
        gatewayMock.sampleRateRangesResult = []
        createSut()
        #expect(sut.device(id: 1)?.availableSampleRates == [])
    }

    // MARK: - devices(_:) filtering

    @Test
    mutating func devicesAllResolvesEveryID() {
        gatewayMock.allDeviceIDsResult = [1, 2]
        gatewayMock.deviceUIDResult = "uid"
        gatewayMock.deviceNameResult = "Device"
        createSut()
        #expect(sut.devices(.all).map(\.id) == [1, 2])
    }

    @Test
    mutating func devicesAllSkipsUnresolvableDevices() {
        gatewayMock.allDeviceIDsResult = [1, 2]
        gatewayMock.deviceUIDResult = nil // nothing resolves
        gatewayMock.deviceNameResult = "Device"
        createSut()
        #expect(sut.devices(.all).isEmpty)
    }

    @Test
    mutating func devicesInputReturnsDevicesWithInputChannels() {
        gatewayMock.allDeviceIDsResult = [1]
        gatewayMock.deviceUIDResult = "uid"
        gatewayMock.deviceNameResult = "Device"
        gatewayMock.streamIDsResult = [10]
        gatewayMock.channelsPerFrameResult = 2
        createSut()
        #expect(sut.devices(.input).map(\.id) == [1])
    }

    @Test
    mutating func devicesInputExcludesDevicesWithoutChannels() {
        gatewayMock.allDeviceIDsResult = [1]
        gatewayMock.deviceUIDResult = "uid"
        gatewayMock.deviceNameResult = "Device"
        gatewayMock.streamIDsResult = [] // no channels on any scope
        createSut()
        #expect(sut.devices(.input).isEmpty)
    }

    @Test
    mutating func devicesOutputReturnsDevicesWithOutputChannels() {
        gatewayMock.allDeviceIDsResult = [1]
        gatewayMock.deviceUIDResult = "uid"
        gatewayMock.deviceNameResult = "Device"
        gatewayMock.streamIDsResult = [10]
        gatewayMock.channelsPerFrameResult = 2
        createSut()
        #expect(sut.devices(.output).map(\.id) == [1])
    }

    @Test
    mutating func devicesInputExcludesSystemAggregateDevices() {
        gatewayMock.allDeviceIDsResult = [1]
        gatewayMock.deviceUIDResult = "CADefaultDeviceAggregate-1234"
        gatewayMock.deviceNameResult = "Device"
        gatewayMock.streamIDsResult = [10]
        gatewayMock.channelsPerFrameResult = 2
        createSut()
        #expect(sut.devices(.input).isEmpty)
    }

    @Test
    mutating func devicesInputExcludesOwnAggregateDevices() {
        gatewayMock.allDeviceIDsResult = [1]
        gatewayMock.deviceUIDResult = AggregateDeviceFactory.uidPrefix + "x"
        gatewayMock.deviceNameResult = "Device"
        gatewayMock.streamIDsResult = [10]
        gatewayMock.channelsPerFrameResult = 2
        createSut()
        #expect(sut.devices(.input).isEmpty)
    }
}
