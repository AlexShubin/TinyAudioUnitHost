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

// MARK: - CoreAudio property helpers

fileprivate extension AudioObjectID {
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
