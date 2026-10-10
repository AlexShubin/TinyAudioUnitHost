//
//  TargetDeviceResolver.swift
//  AudioSettingsKit
//
//  Created by Alex Shubin on 08.10.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

@MainActor
protocol TargetDeviceResolverType {
    func resolve(_ settings: AudioSettings) -> AudioDevice?
}

@MainActor
final class TargetDeviceResolver: TargetDeviceResolverType {
    private let devicesProvider: AudioDevicesProviderType
    private let factory: AggregateDeviceFactoryType
    private var cachedAggregate: CachedAggregate?

    init(devicesProvider: AudioDevicesProviderType, factory: AggregateDeviceFactoryType) {
        self.devicesProvider = devicesProvider
        self.factory = factory
        factory.destroyOrphans()
    }

    func resolve(_ settings: AudioSettings) -> AudioDevice? {
        if let inputDevice = settings.inputDevice,
           let outputDevice = settings.outputDevice,
           inputDevice.id != outputDevice.id {
            return obtainAggregate(inputUID: inputDevice.uid, outputUID: outputDevice.uid)
        }
        destroyCachedAggregate()
        return settings.outputDevice
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
