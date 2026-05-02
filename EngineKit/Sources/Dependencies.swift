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
    public let audioUnitComponentsLibrary: AudioUnitComponentsLibraryType

    public static let live = Dependencies(
        engine: Engine(
            engine: AVAudioEngine(),
            inputMixer: AVAudioMixerNode(),
            avAudioUnitFactory: AVAudioUnitFactory(),
            coreAudioGateway: CoreAudioGateway(),
            coreMidiManager: CoreMidiManager(),
            aggregateDeviceManager: AudioSettingsKit.Dependencies.live.aggregateDeviceManager
        ),
        audioUnitComponentsLibrary: AudioUnitComponentsLibrary()
    )
}
