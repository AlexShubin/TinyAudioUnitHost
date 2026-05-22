//
//  AudioSettingsProvider.swift
//  AudioSettingsKit
//
//  Created by Alex Shubin on 02.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import StorageKit

public protocol AudioSettingsProviderType: Sendable {
    var current: AudioSettings { get }
    func save(_ settings: AudioSettings)
}

public struct AudioSettingsProvider: AudioSettingsProviderType {
    private let rawStore: RawSettingsStoreType
    private let devicesProvider: AudioDevicesProviderType

    public init(
        rawStore: RawSettingsStoreType,
        devicesProvider: AudioDevicesProviderType
    ) {
        self.rawStore = rawStore
        self.devicesProvider = devicesProvider
    }

    public var current: AudioSettings {
        resolve()
    }

    public func save(_ settings: AudioSettings) {
        let inputChannelIDs = settings.inputChannel?.channels.map(\.id) ?? []
        let outputChannelIDs = settings.outputChannel?.channels.map(\.id) ?? []
        let nextInput = settings.inputDevice.map { device in
            RawDeviceSettings(uid: device.uid, name: device.name, selectedChannels: inputChannelIDs)
        }
        let nextOutput = settings.outputDevice.map { device in
            RawDeviceSettings(uid: device.uid, name: device.name, selectedChannels: outputChannelIDs)
        }
        rawStore.save(RawAudioSettings(
            input: nextInput,
            output: nextOutput,
            bufferSize: settings.bufferSize,
            sampleRate: settings.sampleRate
        ))
    }

    private func resolve() -> AudioSettings {
        let raw = rawStore.current
        let devices = devicesProvider.devices(.all)
        let inputDevice = raw.input.flatMap { saved in devices.first { $0.uid == saved.uid } }
        let outputDevice = raw.output.flatMap { saved in devices.first { $0.uid == saved.uid } }
        let inputChannel = SelectedChannel(
            ids: raw.input?.selectedChannels ?? [],
            in: inputDevice?.inputChannels ?? []
        )
        let outputChannel = SelectedChannel(
            ids: raw.output?.selectedChannels ?? [],
            in: outputDevice?.outputChannels ?? []
        )
        return AudioSettings(
            inputDevice: inputDevice,
            outputDevice: outputDevice,
            inputChannel: inputChannel,
            outputChannel: outputChannel,
            bufferSize: raw.bufferSize,
            sampleRate: raw.sampleRate,
            savedInput: raw.input?.saved,
            savedOutput: raw.output?.saved
        )
    }
}

private extension RawDeviceSettings {
    var saved: SavedDevice {
        SavedDevice(uid: uid, name: name, selectedChannelCount: selectedChannels.count)
    }
}

private extension SelectedChannel {
    init?(ids: [UInt32], in channels: [AudioChannel]) {
        let resolved = ids.compactMap { id in channels.first { $0.id == id } }
        self.init(from: resolved)
    }
}
