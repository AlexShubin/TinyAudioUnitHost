//
//  AggregateDeviceFactory.swift
//  EngineKit
//
//  Created by Alex Shubin on 27.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import CoreAudio

protocol AggregateDeviceFactoryType: Sendable {
    func create(inputUID: String, outputUID: String) -> AudioDeviceID?
    func destroy(id: AudioDeviceID)
    func destroyOrphans()
}

struct AggregateDeviceFactory: AggregateDeviceFactoryType {
    static let uidPrefix = "com.alexshubin.TinyAudioUnitHost.aggregate."

    private let devicesProvider: AudioDevicesProviderType

    init(devicesProvider: AudioDevicesProviderType) {
        self.devicesProvider = devicesProvider
    }

    func create(inputUID: String, outputUID: String) -> AudioDeviceID? {
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

    func destroy(id: AudioDeviceID) {
        AudioHardwareDestroyAggregateDevice(id)
    }

    func destroyOrphans() {
        devicesProvider.devices(.all)
            .filter { $0.uid.hasPrefix(Self.uidPrefix) }
            .forEach { AudioHardwareDestroyAggregateDevice($0.id) }
    }
}
