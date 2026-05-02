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

public actor AudioSettingsFacade: AudioSettingsFacadeType {
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
            raw.target.input.uid = inputUID
            raw.target.input.channels = inputChannels
            raw.target.output.uid = outputUID
            raw.target.output.channels = outputChannels
            raw.bufferSize = bufferSize
            raw.sampleRate = sampleRate
        }
    }

    private func resolve() async -> AudioSettings {
        let raw = await rawStore.current()
        let inputDevice = raw.target.input.uid.flatMap(devicesProvider.device(uid:))
        let outputDevice = raw.target.output.uid.flatMap(devicesProvider.device(uid:))
        let inputChannel = SelectedChannel(
            ids: raw.target.input.channels,
            in: inputDevice?.inputChannels ?? []
        )
        let outputChannel = SelectedChannel(
            ids: raw.target.output.channels,
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
