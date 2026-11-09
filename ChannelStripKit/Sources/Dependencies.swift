//
//  Dependencies.swift
//  ChannelStripKit
//
//  Created by Alex Shubin on 27.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AppKit
import AudioToolboxGatewayKit
import AVFoundation
import Common
import CoreMidiGatewayKit

@MainActor
public struct Dependencies: Sendable {
    public let channelStripModel: ChannelStripModelType
    let systemWakeObserver: SystemWakeObserver

    public static let live: Dependencies = {
        let channelStrip = ChannelStrip(
            engine: AVAudioEngine(),
            avAudioUnitFactory: AVAudioUnitFactory(),
            audioConnector: AudioConnector(audioUnitGateway: AudioToolboxGatewayKit.Dependencies.live.audioUnitGateway),
            midiConnector: MidiConnector(coreMidiGateway: CoreMidiGatewayKit.Dependencies.live.coreMidiGateway)
        )
        return Dependencies(
            channelStripModel: ChannelStripModel(channelStrip: channelStrip),
            systemWakeObserver: SystemWakeObserver(
                channelStrip: channelStrip,
                workspaceNotificationCenter: NSWorkspace.shared.notificationCenter
            )
        )
    }()
}
