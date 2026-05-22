//
//  AudioSettingsProvider.swift
//  AudioSettingsKit
//
//  Created by Alex Shubin on 02.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import StorageKit

public protocol AudioSettingsProviderType: Sendable {
    func current() async -> AudioSettings
    func update(_ transform: @Sendable (inout AudioSettings) -> Void) async
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

    public func current() async -> AudioSettings {
        await resolve()
    }

    public func update(_ transform: @Sendable (inout AudioSettings) -> Void) async {
        var copy = await resolve()
        transform(&copy)
        let inputChannelIDs = copy.inputChannel?.channels.map(\.id) ?? []
        let outputChannelIDs = copy.outputChannel?.channels.map(\.id) ?? []
        let nextInput = copy.inputDevice.map { device in
            RawDeviceSettings(uid: device.uid, name: device.name, selectedChannels: inputChannelIDs)
        }
        let nextOutput = copy.outputDevice.map { device in
            RawDeviceSettings(uid: device.uid, name: device.name, selectedChannels: outputChannelIDs)
        }
        let bufferSize = copy.bufferSize
        let sampleRate = copy.sampleRate
        await rawStore.update { raw in
            raw.input = nextInput
            raw.output = nextOutput
            raw.bufferSize = bufferSize
            raw.sampleRate = sampleRate
        }
    }

    private func resolve() async -> AudioSettings {
        let raw = await rawStore.current()
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
