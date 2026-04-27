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
}

public enum AudioDeviceFilter: Sendable {
    case all
    case input
    case output
}

struct AudioDevicesProvider: AudioDevicesProviderType {
    func devices(_ filter: AudioDeviceFilter) -> [AudioDevice] {
        let ids: [AudioDeviceID] = AudioObjectID(kAudioObjectSystemObject)
            .getArray(selector: kAudioHardwarePropertyDevices)
        return ids.compactMap(makeDevice(id:)).filter { device in
            switch filter {
            case .all: true
            case .input: !device.inputChannels.isEmpty
            case .output: !device.outputChannels.isEmpty
            }
        }
    }

    private func makeDevice(id: AudioDeviceID) -> AudioDevice? {
        guard let uid = id.getString(selector: kAudioDevicePropertyDeviceUID),
              let name = id.getString(selector: kAudioObjectPropertyName)
        else { return nil }
        let inputChannelCount = channelCount(deviceID: id, scope: kAudioDevicePropertyScopeInput)
        let outputChannelCount = channelCount(deviceID: id, scope: kAudioDevicePropertyScopeOutput)
        return AudioDevice(id: id,
                           uid: uid,
                           name: name,
                           inputChannels: channels(count: inputChannelCount),
                           outputChannels: channels(count: outputChannelCount))
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
}
