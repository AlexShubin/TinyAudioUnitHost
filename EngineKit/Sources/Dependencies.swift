//
//  Dependencies.swift
//  EngineKit
//
//  Created by Alex Shubin on 27.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AppKit
import AudioSettingsKit
import AVFoundation
import Common

@MainActor
public struct Dependencies: Sendable {
    public let engine: EngineType
    public let midiManager: MidiManagerType
    public let systemWakeObserver: SystemWakeObserverType

    public static let live: Dependencies = {
        let audioSettings = AudioSettingsKit.Dependencies.live.audioSettingsModel
        let midiManager = MidiManager(
            coreMidiGateway: CoreMidiGateway(),
            audioSettings: audioSettings
        )
        let engine = Engine(
            engine: AVAudioEngine(),
            inputMixer: AVAudioMixerNode(),
            avAudioUnitFactory: AVAudioUnitFactory(),
            coreAudioGateway: CoreAudioGateway(),
            midiManager: midiManager,
            audioSettings: audioSettings
        )
        return Dependencies(
            engine: engine,
            midiManager: midiManager,
            systemWakeObserver: SystemWakeObserver(
                engine: engine,
                workspaceNotificationCenter: NSWorkspace.shared.notificationCenter
            )
        )
    }()
}
