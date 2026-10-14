//
//  Dependencies.swift
//  SessionKit
//
//  Created by Alex Shubin on 27.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AppKit
import AudioSettingsKit
import AudioToolboxGatewayKit
import AVFoundation
import Common
import CoreMidiGatewayKit

@MainActor
public struct Dependencies: Sendable {
    public let pluginChain: PluginChainType
    public let midiManager: MidiManagerType
    public let systemWakeObserver: SystemWakeObserverType

    public static let live: Dependencies = {
        let audioSettings = AudioSettingsKit.Dependencies.live.audioSettingsModel
        let midiManager = MidiManager(
            coreMidiGateway: CoreMidiGatewayKit.Dependencies.live.coreMidiGateway,
            audioSettings: audioSettings
        )
        let pluginChain = PluginChain(
            engine: AVAudioEngine(),
            avAudioUnitFactory: AVAudioUnitFactory(),
            hardwareConnector: HardwareConnector(
                audioUnitGateway: AudioToolboxGatewayKit.Dependencies.live.audioUnitGateway,
                audioSettings: audioSettings
            ),
            midiManager: midiManager
        )
        return Dependencies(
            pluginChain: pluginChain,
            midiManager: midiManager,
            systemWakeObserver: SystemWakeObserver(
                pluginChain: pluginChain,
                workspaceNotificationCenter: NSWorkspace.shared.notificationCenter
            )
        )
    }()
}
