//
//  AudioSettingsObserver.swift
//  TinyAudioUnitHost
//
//  Created by Alex Shubin on 08.10.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioSettingsKit
import ChannelStripKit

@MainActor
final class AudioSettingsObserver: AudioSettingsModelDelegate {
    private let audioSettings: AudioSettingsModelType
    private let channelStrip: ChannelStripModelType

    init(audioSettings: AudioSettingsModelType, channelStrip: ChannelStripModelType) {
        self.audioSettings = audioSettings
        self.channelStrip = channelStrip
        audioSettings.delegate = self
    }

    func audioSettingsDidChange() async {
        guard audioSettings.setup == .met, let targetDevice = audioSettings.targetDevice else {
            await channelStrip.updateHardwareSettings(nil)
            return
        }
        let settings = audioSettings.settings
        await channelStrip.updateHardwareSettings(ChannelStripHardwareSettings(
            audio: .init(settings, targetDevice: targetDevice),
            midi: .init(settings)
        ))
    }
}

private extension ChannelStripHardwareSettings.Audio {
    init(_ settings: AudioSettings, targetDevice: AudioDevice) {
        self.init(
            deviceID: targetDevice.id,
            inputDevice: settings.inputDevice.map(Device.init),
            outputDevice: settings.outputDevice.map(Device.init),
            inputChannels: settings.inputChannel?.channels.map(\.id) ?? [],
            outputChannels: settings.outputChannel?.channels.map(\.id) ?? [],
            sampleRate: settings.sampleRate
        )
    }
}

private extension ChannelStripHardwareSettings.Audio.Device {
    init(_ device: AudioDevice) {
        self.init(id: device.id, outputChannelCount: device.outputChannels.count)
    }
}

private extension ChannelStripHardwareSettings.Midi {
    init(_ settings: AudioSettings) {
        self.init(sources: Set(settings.selectedMidiDevices.map(\.ref)))
    }
}
