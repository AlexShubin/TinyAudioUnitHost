//
//  AudioSettingsFacade.swift
//  AudioSettingsKit
//
//  Created by Alex Shubin on 02.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import StorageKit

public protocol AudioSettingsFacadeType: Sendable {
    func current() async -> AudioSettings
    func update(_ transform: @Sendable (inout AudioSettings) -> Void) async
}

public struct AudioSettingsFacade: AudioSettingsFacadeType {
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
        let inputUID = copy.inputDevice?.uid
        let inputChannels = copy.inputChannel?.channels.map(\.id) ?? []
        let outputUID = copy.outputDevice?.uid
        let outputChannels = copy.outputChannel?.channels.map(\.id) ?? []
        let bufferSize = copy.bufferSize
        let sampleRate = copy.sampleRate
        await rawStore.update { raw in
            raw.input.uid = inputUID
            raw.input.selectedChannels = inputChannels
            raw.output.uid = outputUID
            raw.output.selectedChannels = outputChannels
            raw.bufferSize = bufferSize
            raw.sampleRate = sampleRate
        }
    }

    private func resolve() async -> AudioSettings {
        let raw = await rawStore.current()
        let devices = devicesProvider.devices(.all)
        let inputDevice = raw.input.uid.flatMap { uid in devices.first { $0.uid == uid } }
        let outputDevice = raw.output.uid.flatMap { uid in devices.first { $0.uid == uid } }
        let inputChannel = SelectedChannel(
            ids: raw.input.selectedChannels,
            in: inputDevice?.inputChannels ?? []
        )
        let outputChannel = SelectedChannel(
            ids: raw.output.selectedChannels,
            in: outputDevice?.outputChannels ?? []
        )
        return AudioSettings(
            inputDevice: inputDevice,
            outputDevice: outputDevice,
            inputChannel: inputChannel,
            outputChannel: outputChannel,
            bufferSize: raw.bufferSize,
            sampleRate: raw.sampleRate
        )
    }
}

private extension SelectedChannel {
    init?(ids: [UInt32], in channels: [AudioChannel]) {
        let resolved = ids.compactMap { id in channels.first { $0.id == id } }
        self.init(from: resolved)
    }
}
