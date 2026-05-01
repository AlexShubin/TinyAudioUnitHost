//
//  RawAudioSettings.swift
//  StorageKit
//
//  Created by Alex Shubin on 22.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

public struct RawAudioSettings: Sendable, Equatable, Codable {
    public var target: RawTargetDevice
    public var bufferSize: UInt32?
    public var sampleRate: Float64?

    public init(
        target: RawTargetDevice = .empty,
        bufferSize: UInt32? = nil,
        sampleRate: Float64? = nil
    ) {
        self.target = target
        self.bufferSize = bufferSize
        self.sampleRate = sampleRate
    }

    public static let empty = RawAudioSettings()
}
