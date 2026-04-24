//
//  AggregateDeviceManager.swift
//  TinyAudioUnitHost
//
//  Created by Alex Shubin on 24.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import CoreAudio

protocol AggregateDeviceManagerType: Sendable {
    func resolve(_ intent: DeviceBindingIntent) async -> AudioDeviceID?
}

final actor AggregateDeviceManager: AggregateDeviceManagerType {
    static let uidPrefix = "com.alexshubin.TinyAudioUnitHost.aggregate."

    private var currentAggregateID: AudioDeviceID?

    init() {
        destroyOrphans()
    }

    func resolve(_ intent: DeviceBindingIntent) -> AudioDeviceID? {
        if let previous = currentAggregateID {
            AudioHardwareDestroyAggregateDevice(previous)
            currentAggregateID = nil
        }

        switch intent {
        case .none:
            return nil
        case .direct(let id):
            return id
        case .aggregate(let inputID, let outputID):
            let id = create(inputDeviceID: inputID, outputDeviceID: outputID)
            currentAggregateID = id
            return id
        }
    }

    nonisolated private func destroyOrphans() {
        let ids: [AudioDeviceID] = AudioObjectID(kAudioObjectSystemObject)
            .aggregateDeviceIDs()
        for deviceID in ids {
            guard let uid = Self.deviceUID(for: deviceID),
                  uid.hasPrefix(Self.uidPrefix)
            else { continue }
            AudioHardwareDestroyAggregateDevice(deviceID)
        }
    }

    private func create(inputDeviceID: AudioDeviceID, outputDeviceID: AudioDeviceID) -> AudioDeviceID? {
        guard let inputUID = Self.deviceUID(for: inputDeviceID),
              let outputUID = Self.deviceUID(for: outputDeviceID)
        else { return nil }

        let subDevices: [[String: Any]] = [
            [kAudioSubDeviceUIDKey as String: inputUID],
            [kAudioSubDeviceUIDKey as String: outputUID],
        ]

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
