//
//  AudioInputDevicesProvider.swift
//  TinyAudioUnitHost
//
//  Created by Alex Shubin on 22.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import CoreAudio

protocol AudioInputDevicesProviderType: Sendable {
    func inputDevices() -> [AudioInputDevice]
}

struct AudioInputDevicesProvider: AudioInputDevicesProviderType {
    func inputDevices() -> [AudioInputDevice] {
        allDeviceIDs().compactMap(makeInputDevice(id:))
    }

    private func allDeviceIDs() -> [AudioDeviceID] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &address, 0, nil, &dataSize
        ) == noErr else { return [] }

        let count = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var ids = [AudioDeviceID](repeating: 0, count: count)
        guard AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address, 0, nil, &dataSize, &ids
        ) == noErr else { return [] }
        return ids
    }

    private func makeInputDevice(id: AudioDeviceID) -> AudioInputDevice? {
        let channels = inputChannels(deviceID: id)
        guard !channels.isEmpty else { return nil }
        let name = deviceName(id: id) ?? "Unknown device"
        return AudioInputDevice(id: id, name: name, channels: channels)
    }

    private func deviceName(id: AudioDeviceID) -> String? {
        readCFString(
            objectID: id,
            selector: kAudioObjectPropertyName,
            scope: kAudioObjectPropertyScopeGlobal,
            element: kAudioObjectPropertyElementMain
        )
    }

    private func inputChannels(deviceID: AudioDeviceID) -> [AudioInputChannel] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(deviceID, &address, 0, nil, &dataSize) == noErr,
              dataSize > 0
        else { return [] }

        let bufferListPtr = UnsafeMutableRawPointer.allocate(
            byteCount: Int(dataSize),
            alignment: MemoryLayout<AudioBufferList>.alignment
        )
        defer { bufferListPtr.deallocate() }

        guard AudioObjectGetPropertyData(
            deviceID, &address, 0, nil, &dataSize, bufferListPtr
        ) == noErr else { return [] }

        let buffers = UnsafeMutableAudioBufferListPointer(
            bufferListPtr.assumingMemoryBound(to: AudioBufferList.self)
        )
        let totalChannels = buffers.reduce(0) { $0 + Int($1.mNumberChannels) }
        guard totalChannels > 0 else { return [] }

        return (1...totalChannels).map { number in
            let name = channelName(deviceID: deviceID, element: UInt32(number))
                ?? "Channel \(number)"
            return AudioInputChannel(id: UInt32(number), name: name)
        }
    }

    private func channelName(deviceID: AudioDeviceID, element: UInt32) -> String? {
        readCFString(
            objectID: deviceID,
            selector: kAudioObjectPropertyElementName,
            scope: kAudioDevicePropertyScopeInput,
            element: element
        )
    }

    private func readCFString(
        objectID: AudioObjectID,
        selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope,
        element: AudioObjectPropertyElement
    ) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: scope,
            mElement: element
        )
        var result: Unmanaged<CFString>?
        var dataSize = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        let status = AudioObjectGetPropertyData(
            objectID, &address, 0, nil, &dataSize, &result
        )
        guard status == noErr, let result else { return nil }
        let string = result.takeRetainedValue() as String
        return string.isEmpty ? nil : string
    }
}
