//
//  AggregateDeviceFactory.swift
//  TinyAudioUnitHost
//
//  Created by Alex Shubin on 24.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import CoreAudio

protocol AggregateDeviceFactoryType: Sendable {
    func create(inputDeviceID: AudioDeviceID, outputDeviceID: AudioDeviceID) -> AudioDeviceID?
    func destroy(_ deviceID: AudioDeviceID)
    func destroyOrphans()
}

struct AggregateDeviceFactory: AggregateDeviceFactoryType {
    static let uidPrefix = "com.alexshubin.TinyAudioUnitHost.aggregate."

    func create(inputDeviceID: AudioDeviceID, outputDeviceID: AudioDeviceID) -> AudioDeviceID? {
        guard let inputUID = Self.deviceUID(for: inputDeviceID),
              let outputUID = Self.deviceUID(for: outputDeviceID)
        else { return nil }

        // Defensive: manager collapses same-device to a direct bind, but guard
        // here too so the sub-device list can't ever contain duplicates.
        var subDevices: [[String: Any]] = [[kAudioSubDeviceUIDKey as String: outputUID]]
        if inputUID != outputUID {
            subDevices.insert([kAudioSubDeviceUIDKey as String: inputUID], at: 0)
        }

        // Per-create unique UID: destroy is asynchronous, so reusing a fixed
        // UID across rapid reconnect cycles can race.
        let uid = Self.uidPrefix + UUID().uuidString

        let description: [String: Any] = [
            kAudioAggregateDeviceNameKey as String: "TinyAudioUnitHost Aggregate",
            kAudioAggregateDeviceUIDKey as String: uid,
            kAudioAggregateDeviceIsPrivateKey as String: 1,
            kAudioAggregateDeviceIsStackedKey as String: 0,
            kAudioAggregateDeviceMainSubDeviceKey as String: outputUID,
            kAudioAggregateDeviceSubDeviceListKey as String: subDevices,
        ]

        var aggregateID: AudioDeviceID = 0
        let status = AudioHardwareCreateAggregateDevice(description as CFDictionary, &aggregateID)
        return status == noErr ? aggregateID : nil
    }

    func destroy(_ deviceID: AudioDeviceID) {
        AudioHardwareDestroyAggregateDevice(deviceID)
    }

    func destroyOrphans() {
        let ids: [AudioDeviceID] = AudioObjectID(kAudioObjectSystemObject)
            .aggregateDeviceIDs()
        for deviceID in ids {
            guard let uid = Self.deviceUID(for: deviceID),
                  uid.hasPrefix(Self.uidPrefix)
            else { continue }
            AudioHardwareDestroyAggregateDevice(deviceID)
        }
    }

    private static func deviceUID(for deviceID: AudioDeviceID) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceUID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var result: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &result) == noErr,
              let result
        else { return nil }
        let string = result.takeRetainedValue() as String
        return string.isEmpty ? nil : string
    }
}

fileprivate extension AudioObjectID {
    func aggregateDeviceIDs() -> [AudioDeviceID] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(self, &address, 0, nil, &dataSize) == noErr
        else { return [] }
        let count = Int(dataSize) / MemoryLayout<AudioDeviceID>.stride
        guard count > 0 else { return [] }
        return [AudioDeviceID](unsafeUninitializedCapacity: count) { buffer, initialized in
            var size = dataSize
            let status = AudioObjectGetPropertyData(self, &address, 0, nil, &size, buffer.baseAddress!)
            initialized = status == noErr ? count : 0
        }
    }
}
