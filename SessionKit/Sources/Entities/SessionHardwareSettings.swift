//
//  SessionHardwareSettings.swift
//  SessionKit
//
//  Created by Alex Shubin on 15.10.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioSettingsKit

struct SessionHardwareSettings: Equatable {
    struct Audio: Equatable {
        struct Device: Equatable {
            let id: UInt32
            let outputChannelCount: Int
        }

        let deviceID: UInt32
        let inputDevice: Device?
        let outputDevice: Device?
        let inputChannels: [UInt32]
        let outputChannels: [UInt32]
    }

    struct Midi: Equatable {
        /// CoreMIDI endpoints the chain receives MIDI from.
        let sources: Set<UInt32>
    }

    let audio: Audio
    let midi: Midi
}

extension SessionHardwareSettings {
    init(_ settings: AudioSettings, targetDevice: AudioDevice) {
        self.init(audio: Audio(settings, targetDevice: targetDevice), midi: Midi(settings))
    }
}

extension SessionHardwareSettings.Audio {
    init(_ settings: AudioSettings, targetDevice: AudioDevice) {
        self.init(
            deviceID: targetDevice.id,
            inputDevice: settings.inputDevice.map(Device.init),
            outputDevice: settings.outputDevice.map(Device.init),
            inputChannels: settings.inputChannel?.channels.map(\.id) ?? [],
            outputChannels: settings.outputChannel?.channels.map(\.id) ?? []
        )
    }
}

extension SessionHardwareSettings.Audio.Device {
    init(_ device: AudioDevice) {
        self.init(id: device.id, outputChannelCount: device.outputChannels.count)
    }
}

extension SessionHardwareSettings.Midi {
    init(_ settings: AudioSettings) {
        self.init(sources: Set(settings.selectedMidiDevices.map(\.ref)))
    }
}
