//
//  AudioSettings.swift
//  Common
//
//  Created by Alex Shubin on 22.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

public struct DeviceSettings: Sendable, Equatable {
    public var device: AudioDevice?
    public var selectedChannel: SelectedChannel?

    public init(device: AudioDevice?, selectedChannel: SelectedChannel?) {
        self.device = device
        self.selectedChannel = selectedChannel
    }

    public static let empty = DeviceSettings(device: nil, selectedChannel: nil)
}

public struct AudioSettings: Sendable, Equatable {
    public var input: DeviceSettings
    public var output: DeviceSettings
    public var bufferSize: UInt32?

    public init(input: DeviceSettings, output: DeviceSettings, bufferSize: UInt32? = nil) {
        self.input = input
        self.output = output
        self.bufferSize = bufferSize
    }

    public static let empty = AudioSettings(input: .empty, output: .empty)
}
