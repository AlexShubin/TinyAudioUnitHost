//
//  Dependencies.swift
//  SessionKit
//
//  Created by Alex Shubin on 27.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AppKit
import AudioToolboxGatewayKit
import AVFoundation
import Common
import CoreMidiGatewayKit
import PresetKit

@MainActor
public struct Dependencies: Sendable {
    public let sessionModel: SessionModelType
    let systemWakeObserver: SystemWakeObserver

    public static let live: Dependencies = {
        let channelStrip = ChannelStrip(
            engine: AVAudioEngine(),
            avAudioUnitFactory: AVAudioUnitFactory(),
            audioConnector: AudioConnector(audioUnitGateway: AudioToolboxGatewayKit.Dependencies.live.audioUnitGateway),
            midiConnector: MidiConnector(coreMidiGateway: CoreMidiGatewayKit.Dependencies.live.coreMidiGateway)
        )
        return Dependencies(
            sessionModel: SessionModel(
                channelStrip: channelStrip,
                presetProvider: PresetKit.Dependencies.live.presetProvider
            ),
            systemWakeObserver: SystemWakeObserver(
                channelStrip: channelStrip,
                workspaceNotificationCenter: NSWorkspace.shared.notificationCenter
            )
        )
    }()
}
