//
//  TargetSettingsProvider.swift
//  AudioSettingsKit
//
//  Created by Alex Shubin on 24.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

public protocol TargetSettingsProviderType: Sendable {
    func resolveTarget() async -> TargetSettings?
}

final actor TargetSettingsProvider: TargetSettingsProviderType {
    private let audioSettings: AudioSettingsProviderType
    private let devicesProvider: AudioDevicesProviderType
    private let factory: AggregateDeviceFactoryType
    private var cachedAggregate: CachedAggregate?

    init(
        audioSettings: AudioSettingsProviderType,
        devicesProvider: AudioDevicesProviderType,
        factory: AggregateDeviceFactoryType
    ) {
        self.audioSettings = audioSettings
        self.devicesProvider = devicesProvider
        self.factory = factory
        factory.destroyOrphans()
    }

    func resolveTarget() async -> TargetSettings? {
        let settings = await audioSettings.current()
        return resolve(settings)
    }

    private func resolve(_ settings: AudioSettings) -> TargetSettings? {
        let targetDevice: AudioDevice?
        if let inputDevice = settings.inputDevice,
           let outputDevice = settings.outputDevice,
           inputDevice.id != outputDevice.id {
            targetDevice = obtainAggregate(inputUID: inputDevice.uid, outputUID: outputDevice.uid)
        } else {
            destroyCachedAggregate()
            targetDevice = settings.outputDevice
        }
        return targetDevice.map {
            .init(settings: settings, device: $0)
        }
    }

    private func obtainAggregate(inputUID: String, outputUID: String) -> AudioDevice? {
        if let cached = cachedAggregate,
           cached.inputUID == inputUID,
           cached.outputUID == outputUID,
           let live = devicesProvider.device(id: cached.id) {
            return live
        }
        destroyCachedAggregate()
        guard let id = factory.create(inputUID: inputUID, outputUID: outputUID),
              let aggregate = devicesProvider.device(id: id) else { return nil }
        cachedAggregate = CachedAggregate(inputUID: inputUID, outputUID: outputUID, id: id)
        return aggregate
    }

    private func destroyCachedAggregate() {
        if let cached = cachedAggregate {
            factory.destroy(id: cached.id)
        }
        cachedAggregate = nil
    }

    private struct CachedAggregate {
        let inputUID: String
        let outputUID: String
        let id: UInt32
    }
}
