//
//  AudioSettings.swift
//  AudioSettingsKit
//
//  Created by Alex Shubin on 02.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

public struct AudioSettings: Sendable, Equatable {
    public let inputDevice: AudioDevice?
    public let outputDevice: AudioDevice?
    public let inputChannel: SelectedChannel?
    public let outputChannel: SelectedChannel?
    public let bufferSize: UInt32?
    public let sampleRate: Float64?
    public let savedInput: SavedDevice?
    public let savedOutput: SavedDevice?

    public init(
        inputDevice: AudioDevice? = nil,
        outputDevice: AudioDevice? = nil,
        inputChannel: SelectedChannel? = nil,
        outputChannel: SelectedChannel? = nil,
        bufferSize: UInt32? = nil,
        sampleRate: Float64? = nil,
        savedInput: SavedDevice? = nil,
        savedOutput: SavedDevice? = nil
    ) {
        self.inputDevice = inputDevice
        self.outputDevice = outputDevice
        self.inputChannel = inputChannel
        self.outputChannel = outputChannel
        self.bufferSize = bufferSize
        self.sampleRate = sampleRate
        self.savedInput = savedInput
        self.savedOutput = savedOutput
    }

    public static let empty = AudioSettings()
}
