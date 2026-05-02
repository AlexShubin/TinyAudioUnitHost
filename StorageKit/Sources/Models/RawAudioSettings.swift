//
//  RawAudioSettings.swift
//  StorageKit
//
//  Created by Alex Shubin on 22.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

public struct RawAudioSettings: Sendable, Equatable, Codable {
    public var input: RawDeviceSettings
    public var output: RawDeviceSettings
    public var bufferSize: UInt32?
    public var sampleRate: Float64?

    public init(
        input: RawDeviceSettings = .empty,
        output: RawDeviceSettings = .empty,
        bufferSize: UInt32? = nil,
        sampleRate: Float64? = nil
    ) {
        self.input = input
        self.output = output
        self.bufferSize = bufferSize
        self.sampleRate = sampleRate
    }

    public static let empty = RawAudioSettings()
}
