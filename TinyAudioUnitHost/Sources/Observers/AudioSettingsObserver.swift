//
//  AudioSettingsObserver.swift
//  TinyAudioUnitHost
//
//  Created by Alex Shubin on 08.10.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioSettingsKit
import EngineKit

@MainActor
protocol AudioSettingsObserverType: AnyObject {
    func start()
}

@MainActor
final class AudioSettingsObserver: AudioSettingsObserverType, AudioSettingsModelDelegate {
    private let audioSettings: AudioSettingsModelType
    private let engine: EngineType
    private let midiManager: MidiManagerType
    private let session: SessionModelType
    private var appliedBinding: AudioBinding?

    init(
        audioSettings: AudioSettingsModelType,
        engine: EngineType,
        midiManager: MidiManagerType,
        session: SessionModelType
    ) {
        self.audioSettings = audioSettings
        self.engine = engine
        self.midiManager = midiManager
        self.session = session
    }

    func start() {
        audioSettings.delegate = self
    }

    func audioSettingsDidChange() async {
        let binding = AudioBinding(settings: audioSettings.settings, targetDevice: audioSettings.targetDevice)
        if binding != appliedBinding {
            appliedBinding = binding
            try? await engine.reload()
        }
        await midiManager.reconnectMIDISources()
        await session.refreshSetup()
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

    init(settings: AudioSettings, targetDevice: AudioDevice?) {
        inputDevice = settings.inputDevice
        outputDevice = settings.outputDevice
        inputChannel = settings.inputChannel
        outputChannel = settings.outputChannel
        bufferSize = settings.bufferSize
        sampleRate = settings.sampleRate
        self.targetDevice = targetDevice
    }
}
