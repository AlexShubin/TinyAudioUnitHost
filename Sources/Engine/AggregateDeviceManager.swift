//
//  AggregateDeviceManager.swift
//  TinyAudioUnitHost
//
//  Created by Alex Shubin on 24.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import CoreAudio

protocol AggregateDeviceManagerType: Sendable {
    func create(inputUID: String, outputUID: String) async -> AudioDeviceID?
    func destroy() async
}

final actor AggregateDeviceManager: AggregateDeviceManagerType {
    static let uidPrefix = "com.alexshubin.TinyAudioUnitHost.aggregate."

    private var currentAggregateID: AudioDeviceID?

    init() {
        destroyOrphans()
    }

    func create(inputUID: String, outputUID: String) -> AudioDeviceID? {
        destroy()
        let id = makeAggregate(inputUID: inputUID, outputUID: outputUID)
        currentAggregateID = id
        return id
    }

    func destroy() {
        guard let previous = currentAggregateID else { return }
        AudioHardwareDestroyAggregateDevice(previous)
        currentAggregateID = nil
    }

    nonisolated private func destroyOrphans() {
        let ids: [AudioDeviceID] = AudioObjectID(kAudioObjectSystemObject)
            .getArray(selector: kAudioHardwarePropertyDevices)
        for deviceID in ids {
            guard let uid = deviceID.getString(selector: kAudioDevicePropertyDeviceUID),
                  uid.hasPrefix(Self.uidPrefix)
            else { continue }
            AudioHardwareDestroyAggregateDevice(deviceID)
        }
    }

    private func makeAggregate(inputUID: String, outputUID: String) -> AudioDeviceID? {
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

}
