//
//  AudioDevicesProvider.swift
//  AudioSettingsKit
//
//  Created by Alex Shubin on 22.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

public protocol AudioDevicesProviderType: Sendable {
    @concurrent
    func scanDevices() async -> [AudioDevice]
    func device(id: UInt32) -> AudioDevice?
}

struct AudioDevicesProvider: AudioDevicesProviderType {
    private static let candidateBufferSizes: [UInt32] = [16, 32, 64, 128, 256, 512]
    private static let candidateSampleRates: [Float64] = [44_100, 48_000, 88_200, 96_000, 176_400, 192_000]

    private let gateway: CoreAudioGatewayType

    init(gateway: CoreAudioGatewayType) {
        self.gateway = gateway
    }

    @concurrent
    func scanDevices() async -> [AudioDevice] {
        gateway.allDeviceIDs.compactMap(device(id:))
    }

    func device(id: UInt32) -> AudioDevice? {
        guard let uid = gateway.deviceUID(of: id),
              let name = gateway.deviceName(of: id)
        else { return nil }
        return AudioDevice(id: id,
                           uid: uid,
                           name: name,
                           inputChannels: channels(deviceID: id, scope: .input),
                           outputChannels: channels(deviceID: id, scope: .output),
                           availableBufferSizes: bufferSizes(deviceID: id),
                           availableSampleRates: sampleRates(deviceID: id))
    }

    private func channels(deviceID: UInt32, scope: AudioDeviceScope) -> [AudioChannel] {
        let count = channelCount(deviceID: deviceID, scope: scope)
        guard count > 0 else { return [] }
        return (1...count).map { index in
            let channel = UInt32(index)
            let name = gateway.channelName(of: deviceID, scope: scope, channel: channel) ?? "Channel \(index)"
            return AudioChannel(id: channel, name: name)
        }
    }

    private func channelCount(deviceID: UInt32, scope: AudioDeviceScope) -> Int {
        gateway.streamIDs(of: deviceID, scope: scope).reduce(0) { total, streamID in
            total + gateway.channelsPerFrame(of: streamID)
        }
    }

    private func bufferSizes(deviceID: UInt32) -> [UInt32] {
        guard let range = gateway.bufferSizeRange(of: deviceID) else { return [] }
        return Self.candidateBufferSizes.filter { range.contains(Double($0)) }
    }

    private func sampleRates(deviceID: UInt32) -> [Float64] {
        let ranges = gateway.sampleRateRanges(of: deviceID)
        guard !ranges.isEmpty else { return [] }
        return Self.candidateSampleRates.filter { rate in
            ranges.contains { $0.contains(rate) }
        }
    }
}
