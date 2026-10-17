//
//  AudioSettingsObserver.swift
//  TinyAudioUnitHost
//
//  Created by Alex Shubin on 08.10.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioSettingsKit
import SessionKit

@MainActor
final class AudioSettingsObserver: AudioSettingsModelDelegate {
    private let audioSettings: AudioSettingsModelType
    private let session: SessionModelType

    init(audioSettings: AudioSettingsModelType, session: SessionModelType) {
        self.audioSettings = audioSettings
        self.session = session
        audioSettings.delegate = self
    }

    func audioSettingsDidChange() async {
        await session.updateHardwareSettings(SessionHardwareSettings(audioSettings))
    }
}

private extension SessionHardwareSettings {
    @MainActor
    init?(_ audioSettings: AudioSettingsModelType) {
        guard audioSettings.setup == .met, let targetDevice = audioSettings.targetDevice else { return nil }
        let settings = audioSettings.settings
        self.init(audio: Audio(settings, targetDevice: targetDevice), midi: Midi(settings))
    }
}

private extension SessionHardwareSettings.Audio {
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

private extension SessionHardwareSettings.Audio.Device {
    init(_ device: AudioDevice) {
        self.init(id: device.id, outputChannelCount: device.outputChannels.count)
    }
}

private extension SessionHardwareSettings.Midi {
    init(_ settings: AudioSettings) {
        self.init(sources: Set(settings.selectedMidiDevices.map(\.ref)))
    }
}
