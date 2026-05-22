//
//  RawAudioSettings.swift
//  StorageKit
//
//  Created by Alex Shubin on 22.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

public struct RawAudioSettings: Sendable, Equatable, Codable {
    public let input: RawDeviceSettings?
    public let output: RawDeviceSettings?
    public let bufferSize: UInt32?
    public let sampleRate: Float64?

    public init(
        input: RawDeviceSettings? = nil,
        output: RawDeviceSettings? = nil,
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
