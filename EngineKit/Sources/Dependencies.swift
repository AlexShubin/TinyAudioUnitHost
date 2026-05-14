//
//  Dependencies.swift
//  EngineKit
//
//  Created by Alex Shubin on 27.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioSettingsKit
import AVFoundation

public struct Dependencies: Sendable {
    public let engine: EngineType
    public let engineReloader: EngineReloaderType

    public static let live: Dependencies = {
        let engine = Engine(
            engine: AVAudioEngine(),
            inputMixer: AVAudioMixerNode(),
            avAudioUnitFactory: AVAudioUnitFactory(),
            coreAudioGateway: CoreAudioGateway(),
            coreMidiManager: CoreMidiManager(),
            targetSettingsProvider: AudioSettingsKit.Dependencies.live.targetSettingsProvider
        )
        return Dependencies(
            engine: engine,
            engineReloader: EngineReloader(
                engine: engine,
                notificationCenter: NotificationCenter.default
            )
        )
    }()
}
