//
//  AggregateDeviceManager.swift
//  EngineKit
//
//  Created by Alex Shubin on 24.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import Common
import StorageKit

public protocol AggregateDeviceManagerType: Sendable {
    func resolveTarget() async -> TargetAudioDevice?
}

final actor AggregateDeviceManager: AggregateDeviceManagerType {
    private let devicesProvider: AudioDevicesProviderType
    private let settingsStore: AudioSettingsStoreType
    private let factory: AggregateDeviceFactoryType
    private var cachedTarget: TargetAudioDevice?

    init(
        devicesProvider: AudioDevicesProviderType,
        settingsStore: AudioSettingsStoreType,
        factory: AggregateDeviceFactoryType
    ) {
        self.devicesProvider = devicesProvider
        self.settingsStore = settingsStore
        self.factory = factory
        factory.destroyOrphans()
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
        destroyCachedAggregate()

        switch (input, output) {
        case (nil, nil):
            return nil
        case let (device?, nil):
            return TargetAudioDevice(
                device: device,
                inputSource: device,
                outputSource: nil,
                inputOffset: 0,
                outputOffset: 0
            )
        case let (nil, device?):
            return TargetAudioDevice(
                device: device,
                inputSource: nil,
                outputSource: device,
                inputOffset: 0,
                outputOffset: 0
            )
        case let (input?, output?) where input.id == output.id:
            return TargetAudioDevice(
                device: input,
                inputSource: input,
                outputSource: output,
                inputOffset: 0,
                outputOffset: 0
            )
        case let (input?, output?):
            guard let id = factory.create(inputUID: input.uid, outputUID: output.uid),
                  let aggregate = devicesProvider.device(id: id)
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

    /// Destroys the cached aggregate if the current target is one we created
    /// (both sources non-nil with different IDs ⇒ `device` is the aggregate).
    private func destroyCachedAggregate() {
        guard let cached = cachedTarget,
              let inputSource = cached.inputSource,
              let outputSource = cached.outputSource,
              inputSource.id != outputSource.id else { return }
        factory.destroy(id: cached.device.id)
    }
}
