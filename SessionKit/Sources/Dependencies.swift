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
import PresetKit

@MainActor
public struct Dependencies: Sendable {
    public let sessionModel: SessionModelType
    public let audioSettingsObserver: AudioSettingsObserverType
    public let systemWakeObserver: SystemWakeObserverType

    public static let live: Dependencies = {
        let audioSettings = AudioSettingsKit.Dependencies.live.audioSettingsModel
        let midiConnector = MidiConnector(coreMidiGateway: CoreMidiGatewayKit.Dependencies.live.coreMidiGateway)
        let channelStrip = ChannelStrip(
            engine: AVAudioEngine(),
            avAudioUnitFactory: AVAudioUnitFactory(),
            audioConnector: AudioConnector(audioUnitGateway: AudioToolboxGatewayKit.Dependencies.live.audioUnitGateway),
            midiConnector: midiConnector,
            audioSettings: audioSettings
        )
        return Dependencies(
            sessionModel: SessionModel(
                channelStrip: channelStrip,
                presetProvider: PresetKit.Dependencies.live.presetProvider
            ),
            audioSettingsObserver: AudioSettingsObserver(
                audioSettings: audioSettings,
                channelStrip: channelStrip,
                midiConnector: midiConnector
            ),
            systemWakeObserver: SystemWakeObserver(
                channelStrip: channelStrip,
                workspaceNotificationCenter: NSWorkspace.shared.notificationCenter
            )
        )
    }()
}
