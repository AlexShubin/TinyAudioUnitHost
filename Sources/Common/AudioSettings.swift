//
//  AudioSettings.swift
//  TinyAudioUnitHost
//
//  Created by Alex Shubin on 22.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

struct DeviceSettings: Sendable, Equatable {
    var device: AudioDevice?
    var selectedChannel: SelectedChannel?

    static let empty = DeviceSettings(device: nil, selectedChannel: nil)
}

struct AudioSettings: Sendable, Equatable {
    var input: DeviceSettings
    var output: DeviceSettings

    static let empty = AudioSettings(input: .empty, output: .empty)
}
