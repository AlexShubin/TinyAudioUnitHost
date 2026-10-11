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
    private var appliedBinding: AudioBinding?

    init(
        audioSettings: AudioSettingsModelType,
        engine: EngineType,
        midiManager: MidiManagerType
    ) {
        self.audioSettings = audioSettings
        self.engine = engine
        self.midiManager = midiManager
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
            await engine.reload()
        }
        await midiManager.reconnectMIDISources()
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
