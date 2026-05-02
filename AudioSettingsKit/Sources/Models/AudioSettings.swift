//
//  AudioSettings.swift
//  AudioSettingsKit
//
//  Created by Alex Shubin on 02.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

public struct AudioSettings: Sendable, Equatable {
    public var inputDevice: AudioDevice?
    public var outputDevice: AudioDevice?
    public var inputChannel: SelectedChannel?
    public var outputChannel: SelectedChannel?
    public var bufferSize: UInt32?
    public var sampleRate: Float64?

    public init(
        inputDevice: AudioDevice? = nil,
        outputDevice: AudioDevice? = nil,
        inputChannel: SelectedChannel? = nil,
        outputChannel: SelectedChannel? = nil,
        bufferSize: UInt32? = nil,
        sampleRate: Float64? = nil
    ) {
        self.inputDevice = inputDevice
        self.outputDevice = outputDevice
        self.inputChannel = inputChannel
        self.outputChannel = outputChannel
        self.bufferSize = bufferSize
        self.sampleRate = sampleRate
    }

    public static let empty = AudioSettings()
}
