//
//  SessionAudioSettings.swift
//  SessionKit
//
//  Created by Alex Shubin on 15.10.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioSettingsKit

struct SessionAudioSettings: Equatable {
    struct Audio: Equatable {
        let deviceID: UInt32
        let isInputEnabled: Bool
        let isOutputEnabled: Bool
        /// Zero-based device channels feeding the chain; empty when no input is selected.
        let inputChannels: [Int]
        /// Zero-based channels in the device's physical layout that the chain plays to.
        let outputChannels: [Int]
    }

    struct Midi: Equatable {
        /// CoreMIDI endpoints the chain receives MIDI from.
        let sources: Set<UInt32>
    }

    let audio: Audio
    let midi: Midi
}

extension SessionAudioSettings {
    init(_ settings: AudioSettings, targetDevice: AudioDevice) {
        self.init(audio: Audio(settings, targetDevice: targetDevice), midi: Midi(settings))
    }
}

extension SessionAudioSettings.Audio {
    init(_ settings: AudioSettings, targetDevice: AudioDevice) {
        let outputOffset = settings.outputOffset
        self.init(
            deviceID: targetDevice.id,
            isInputEnabled: settings.inputDevice != nil,
            isOutputEnabled: settings.outputDevice != nil,
            inputChannels: settings.inputChannel?.channels.map { Int($0.id) - 1 } ?? [],
            outputChannels: settings.outputChannel?.channels.map { outputOffset + Int($0.id) - 1 } ?? []
        )
    }
}

extension SessionAudioSettings.Midi {
    init(_ settings: AudioSettings) {
        self.init(sources: Set(settings.selectedMidiDevices.map(\.ref)))
    }
}

private extension AudioSettings {
    /// Output position in the aggregate's physical channel layout.
    /// Sub-devices are listed [input, output], so output's channels start
    /// after the input device's output channels in the combined layout.
    var outputOffset: Int {
        guard let input = inputDevice,
              let output = outputDevice,
              input.id != output.id else { return 0 }
        return input.outputChannels.count
    }
}
