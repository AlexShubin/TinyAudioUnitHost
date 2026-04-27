//
//  AggregateDeviceManager.swift
//  EngineKit
//
//  Created by Alex Shubin on 24.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import Common
import CoreAudio

public protocol AggregateDeviceManagerType: Sendable {
    func resolve(input: AudioDevice?, output: AudioDevice?) async -> TargetAudioDevice?
}

final actor AggregateDeviceManager: AggregateDeviceManagerType {
    static let uidPrefix = "com.alexshubin.TinyAudioUnitHost.aggregate."

    private let devicesProvider: AudioDevicesProviderType
    private var currentAggregateID: AudioDeviceID?

    init(devicesProvider: AudioDevicesProviderType) {
        self.devicesProvider = devicesProvider
        destroyOrphans()
    }

    func resolve(input: AudioDevice?, output: AudioDevice?) -> TargetAudioDevice? {
        switch (input, output) {
        case (nil, nil):
            destroy()
            return nil
        case let (device?, nil), let (nil, device?):
            destroy()
            return TargetAudioDevice(device: device, inputOffset: 0, outputOffset: 0)
        case let (input?, output?) where input.id == output.id:
            destroy()
            return TargetAudioDevice(device: input, inputOffset: 0, outputOffset: 0)
        case let (input?, output?):
            guard let aggregate = createAggregate(inputUID: input.uid, outputUID: output.uid)
            else { return nil }
            return TargetAudioDevice(
                device: aggregate,
                inputOffset: 0,
                outputOffset: input.outputChannels.count
            )
        }
    }

    private func createAggregate(inputUID: String, outputUID: String) -> AudioDevice? {
        destroy()
        guard let id = makeAggregate(inputUID: inputUID, outputUID: outputUID) else { return nil }
        currentAggregateID = id
        return devicesProvider.device(id: id)
    }

    private func destroy() {
        guard let previous = currentAggregateID else { return }
        AudioHardwareDestroyAggregateDevice(previous)
        currentAggregateID = nil
    }

    nonisolated private func destroyOrphans() {
        devicesProvider.devices(.all)
            .filter { $0.uid.hasPrefix(Self.uidPrefix) }
            .forEach { AudioHardwareDestroyAggregateDevice($0.id) }
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
