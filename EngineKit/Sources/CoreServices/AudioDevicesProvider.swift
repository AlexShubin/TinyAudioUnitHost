//
//  AudioDevicesProvider.swift
//  EngineKit
//
//  Created by Alex Shubin on 22.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import CoreAudio
import Common

public protocol AudioDevicesProviderType: Sendable {
    func devices(_ filter: AudioDeviceFilter) -> [AudioDevice]
    func device(id: AudioDeviceID) -> AudioDevice?
}

public enum AudioDeviceFilter: Sendable {
    case all
    case input
    case output
}

struct AudioDevicesProvider: AudioDevicesProviderType {
    private static let candidateBufferSizes: [UInt32] = [
        16, 32, 64,
        96, 128, 160, 192, 224, 256, 288, 320, 352, 384, 416, 448, 480, 512,
    ]

    func devices(_ filter: AudioDeviceFilter) -> [AudioDevice] {
        let ids: [AudioDeviceID] = AudioObjectID(kAudioObjectSystemObject)
            .getArray(selector: kAudioHardwarePropertyDevices)
        return ids.compactMap(device(id:)).filter { device in
            switch filter {
            case .all: true
            case .input: !device.inputChannels.isEmpty
            case .output: !device.outputChannels.isEmpty
            }
        }
    }

    func device(id: AudioDeviceID) -> AudioDevice? {
        guard let uid = id.getString(selector: kAudioDevicePropertyDeviceUID),
              let name = id.getString(selector: kAudioObjectPropertyName)
        else { return nil }
        let inputChannelCount = channelCount(deviceID: id, scope: kAudioDevicePropertyScopeInput)
        let outputChannelCount = channelCount(deviceID: id, scope: kAudioDevicePropertyScopeOutput)
        return AudioDevice(id: id,
                           uid: uid,
                           name: name,
                           inputChannels: channels(count: inputChannelCount),
                           outputChannels: channels(count: outputChannelCount),
                           availableBufferSizes: bufferSizes(deviceID: id))
    }

    private func channels(count: Int) -> [AudioChannel] {
        guard count > 0 else { return [] }
        return (1...count).map { AudioChannel(id: UInt32($0), name: "Channel \($0)") }
    }

    private func channelCount(deviceID: AudioDeviceID, scope: AudioObjectPropertyScope) -> Int {
        let streamIDs: [AudioStreamID] = deviceID.getArray(selector: kAudioDevicePropertyStreams,
                                                           scope: scope)
        return streamIDs.reduce(0) { total, streamID in
            let format: AudioStreamBasicDescription? = streamID.getProperty(
                selector: kAudioStreamPropertyPhysicalFormat,
                defaultValue: AudioStreamBasicDescription()
            )
            return total + Int(format?.mChannelsPerFrame ?? 0)
        }
    }

    private func bufferSizes(deviceID: AudioDeviceID) -> [UInt32] {
        guard let range: AudioValueRange = deviceID.getProperty(
            selector: kAudioDevicePropertyBufferFrameSizeRange,
            defaultValue: AudioValueRange()
        ) else { return [] }
        return Self.candidateBufferSizes.filter {
            Double($0) >= range.mMinimum && Double($0) <= range.mMaximum
        }
    }
}
