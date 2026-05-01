//
//  AudioSettings.swift
//  StorageKit
//
//  Created by Alex Shubin on 22.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import Common

public struct DeviceSettings: Sendable, Equatable, Codable {
    public var deviceUID: String?
    public var selectedChannelIDs: [UInt32]?

    public init(deviceUID: String?, selectedChannelIDs: [UInt32]?) {
        self.deviceUID = deviceUID
        self.selectedChannelIDs = selectedChannelIDs
    }

    public static let empty = DeviceSettings(deviceUID: nil, selectedChannelIDs: nil)
}

public struct AudioSettings: Sendable, Equatable, Codable {
    public var input: DeviceSettings
    public var output: DeviceSettings
    public var bufferSize: UInt32?
    public var sampleRate: Float64?

    public init(
        input: DeviceSettings,
        output: DeviceSettings,
        bufferSize: UInt32? = nil,
        sampleRate: Float64? = nil
    ) {
        self.input = input
        self.output = output
        self.bufferSize = bufferSize
        self.sampleRate = sampleRate
    }

    public static let empty = AudioSettings(input: .empty, output: .empty)
}
