//
//  AggregateDeviceManager.swift
//  EngineKit
//
//  Created by Alex Shubin on 24.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import Common
import CoreAudio
import StorageKit

public protocol AggregateDeviceManagerType: Sendable {
    func resolveTarget() async -> TargetAudioDevice?
}

final actor AggregateDeviceManager: AggregateDeviceManagerType {
    static let uidPrefix = "com.alexshubin.TinyAudioUnitHost.aggregate."

    private let devicesProvider: AudioDevicesProviderType
    private let settingsStore: AudioSettingsStoreType
    private var cachedTarget: TargetAudioDevice?

    init(devicesProvider: AudioDevicesProviderType, settingsStore: AudioSettingsStoreType) {
        self.devicesProvider = devicesProvider
        self.settingsStore = settingsStore
        destroyOrphans()
    }

    func resolveTarget() async -> TargetAudioDevice? {
        let settings = await settingsStore.current()
        let input = settings.input.device
        let output = settings.output.device

        if input?.id == cachedTarget?.inputSource?.id
            && output?.id == cachedTarget?.outputSource?.id
        {
            return cachedTarget
        }

        cachedTarget = resolve(input: input, output: output)
        return cachedTarget
    }

    private func resolve(input: AudioDevice?, output: AudioDevice?) -> TargetAudioDevice? {
        switch (input, output) {
        case (nil, nil):
            destroyCurrentAggregate()
            return nil
        case let (device?, nil):
            destroyCurrentAggregate()
            return TargetAudioDevice(
                device: device,
                inputSource: device,
                outputSource: nil,
                inputOffset: 0,
                outputOffset: 0
            )
        case let (nil, device?):
            destroyCurrentAggregate()
            return TargetAudioDevice(
                device: device,
                inputSource: nil,
                outputSource: device,
                inputOffset: 0,
                outputOffset: 0
            )
        case let (input?, output?) where input.id == output.id:
            destroyCurrentAggregate()
            return TargetAudioDevice(
                device: input,
                inputSource: input,
                outputSource: output,
                inputOffset: 0,
                outputOffset: 0
            )
        case let (input?, output?):
            guard let aggregate = createAggregate(inputUID: input.uid, outputUID: output.uid)
            else { return nil }
            return TargetAudioDevice(
                device: aggregate,
                inputSource: input,
                outputSource: output,
                inputOffset: 0,
                outputOffset: input.outputChannels.count
            )
        }
    }

    private func createAggregate(inputUID: String, outputUID: String) -> AudioDevice? {
        destroyCurrentAggregate()
        guard let id = makeAggregate(inputUID: inputUID, outputUID: outputUID) else { return nil }
        return devicesProvider.device(id: id)
    }

    private func destroyCurrentAggregate() {
        guard let device = cachedTarget?.device,
              device.uid.hasPrefix(Self.uidPrefix) else { return }
        AudioHardwareDestroyAggregateDevice(device.id)
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
