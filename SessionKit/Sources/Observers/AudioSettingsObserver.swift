//
//  AudioSettingsObserver.swift
//  SessionKit
//
//  Created by Alex Shubin on 08.10.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioSettingsKit

@MainActor
public protocol AudioSettingsObserverType: AnyObject {
    func start()
}

@MainActor
final class AudioSettingsObserver: AudioSettingsObserverType, AudioSettingsModelDelegate {
    private let audioSettings: AudioSettingsModelType
    private let channelStrip: ChannelStripType
    private let midiConnector: MidiConnectorType
    private var appliedBinding: AudioBinding?

    init(
        audioSettings: AudioSettingsModelType,
        channelStrip: ChannelStripType,
        midiConnector: MidiConnectorType
    ) {
        self.audioSettings = audioSettings
        self.channelStrip = channelStrip
        self.midiConnector = midiConnector
    }

    func start() {
        audioSettings.delegate = self
    }

    func audioSettingsDidChange() async {
        let binding = AudioBinding(
            settings: audioSettings.settings,
            targetDevice: audioSettings.targetDevice,
            setup: audioSettings.setup
        )
        if binding != appliedBinding {
            appliedBinding = binding
            await channelStrip.reconnect()
        }
        await midiConnector.reconnect(settings: SessionHardwareSettings.Midi(audioSettings.settings))
    }
}

private struct AudioBinding: Equatable {
    let inputDevice: AudioDevice?
    let outputDevice: AudioDevice?
    let inputChannel: SelectedChannel?
    let outputChannel: SelectedChannel?
    let bufferSize: UInt32?
    let sampleRate: Float64?
    let targetDevice: AudioDevice?
    let setup: SetupState

    init(settings: AudioSettings, targetDevice: AudioDevice?, setup: SetupState) {
        inputDevice = settings.inputDevice
        outputDevice = settings.outputDevice
        inputChannel = settings.inputChannel
        outputChannel = settings.outputChannel
        bufferSize = settings.bufferSize
        sampleRate = settings.sampleRate
        self.targetDevice = targetDevice
        self.setup = setup
    }
}
