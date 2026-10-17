//
//  SessionHardwareSettings.swift
//  SessionKit
//
//  Created by Alex Shubin on 15.10.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

public struct SessionHardwareSettings: Sendable, Equatable {
    public struct Audio: Sendable, Equatable {
        public struct Device: Sendable, Equatable {
            public let id: UInt32
            public let outputChannelCount: Int

            public init(id: UInt32, outputChannelCount: Int) {
                self.id = id
                self.outputChannelCount = outputChannelCount
            }
        }

        public let deviceID: UInt32
        public let inputDevice: Device?
        public let outputDevice: Device?
        public let inputChannels: [UInt32]
        public let outputChannels: [UInt32]
        /// Connections are built at the hardware sample rate, so a change needs the strip reconnected.
        public let sampleRate: Float64?

        public init(
            deviceID: UInt32,
            inputDevice: Device?,
            outputDevice: Device?,
            inputChannels: [UInt32],
            outputChannels: [UInt32],
            sampleRate: Float64?
        ) {
            self.deviceID = deviceID
            self.inputDevice = inputDevice
            self.outputDevice = outputDevice
            self.inputChannels = inputChannels
            self.outputChannels = outputChannels
            self.sampleRate = sampleRate
        }
    }

    public struct Midi: Sendable, Equatable {
        /// CoreMIDI endpoints the chain receives MIDI from.
        public let sources: Set<UInt32>

        public init(sources: Set<UInt32>) {
            self.sources = sources
        }
    }

    public let audio: Audio
    public let midi: Midi

    public init(audio: Audio, midi: Midi) {
        self.audio = audio
        self.midi = midi
    }
}
