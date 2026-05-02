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
    private let facade: AudioSettingsFacadeType
    private let devicesProvider: AudioDevicesProviderType
    private let factory: AggregateDeviceFactoryType
    private var cachedAggregate: CachedAggregate?

    init(
        facade: AudioSettingsFacadeType,
        devicesProvider: AudioDevicesProviderType
    ) {
        self.facade = facade
        self.devicesProvider = devicesProvider
        self.factory = AggregateDeviceFactory(devicesProvider: devicesProvider)
        factory.destroyOrphans()
    }

    func resolveTarget() async -> TargetSettings? {
        let settings = await facade.current()
        return resolve(settings)
    }

    private func resolve(_ settings: AudioSettings) -> TargetSettings? {
        switch (settings.inputDevice, settings.outputDevice) {
        case (nil, nil):
            destroyCachedAggregate()
            return nil
        case let (device?, nil):
            destroyCachedAggregate()
            return TargetSettings(settings: settings, device: device)
        case let (nil, device?):
            destroyCachedAggregate()
            return TargetSettings(settings: settings, device: device)
        case let (input?, output?) where input.id == output.id:
            destroyCachedAggregate()
            return TargetSettings(settings: settings, device: input)
        case let (input?, output?):
            guard let aggregate = obtainAggregate(inputUID: input.uid, outputUID: output.uid) else {
                return nil
            }
            return TargetSettings(settings: settings, device: aggregate)
        }
    }

    private func obtainAggregate(inputUID: String, outputUID: String) -> AudioDevice? {
        if let cached = cachedAggregate,
           cached.inputUID == inputUID,
           cached.outputUID == outputUID,
           let live = devicesProvider.device(id: cached.device.id) {
            return live
        }
        destroyCachedAggregate()
        guard let id = factory.create(inputUID: inputUID, outputUID: outputUID),
              let aggregate = devicesProvider.device(id: id) else { return nil }
        cachedAggregate = CachedAggregate(inputUID: inputUID, outputUID: outputUID, device: aggregate)
        return aggregate
    }

    private func destroyCachedAggregate() {
        if let cached = cachedAggregate {
            factory.destroy(id: cached.device.id)
        }
        cachedAggregate = nil
    }

    private struct CachedAggregate {
        let inputUID: String
        let outputUID: String
        let device: AudioDevice
    }
}
