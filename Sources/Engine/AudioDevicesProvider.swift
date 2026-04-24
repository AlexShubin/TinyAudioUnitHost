//
//  AudioDevicesProvider.swift
//  TinyAudioUnitHost
//
//  Created by Alex Shubin on 22.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import CoreAudio

protocol AudioDevicesProviderType: Sendable {
    func devices() -> [AudioDevice]
}

struct AudioDevicesProvider: AudioDevicesProviderType {
    func devices() -> [AudioDevice] {
        let ids: [AudioDeviceID] = AudioObjectID(kAudioObjectSystemObject)
            .getArray(selector: kAudioHardwarePropertyDevices)
        return ids.compactMap(makeDevice(id:))
    }

    private func makeDevice(id: AudioDeviceID) -> AudioDevice? {
        let inputChannelCount = channelCount(deviceID: id, scope: kAudioDevicePropertyScopeInput)
        let outputChannelCount = channelCount(deviceID: id, scope: kAudioDevicePropertyScopeOutput)
        guard let uid = id.getString(selector: kAudioDevicePropertyDeviceUID),
              let name: String = id.getString(selector: kAudioObjectPropertyName),
                (inputChannelCount > 0 || outputChannelCount > 0) else {
            return nil
        }
        
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

