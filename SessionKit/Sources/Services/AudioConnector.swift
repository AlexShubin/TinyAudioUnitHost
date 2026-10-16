//
//  AudioConnector.swift
//  SessionKit
//
//  Created by Alex Shubin on 14.10.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioToolboxGatewayKit
import AVFoundation
import OSLog

/// Connects the plug-in chain's ends to the audio device: device binding, I/O, channel maps, input and output.
protocol AudioConnectorType: Sendable {
    func connect(first: AVAudioUnit, last: AVAudioUnit, to settings: SessionAudioSettings.Audio, in engine: AVAudioEngineType) -> Bool
    func disconnect(in engine: AVAudioEngineType)
}

struct AudioConnector: AudioConnectorType {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "AudioConnector")

    let audioUnitGateway: AudioUnitGatewayType

    func connect(first: AVAudioUnit, last: AVAudioUnit, to settings: SessionAudioSettings.Audio, in engine: AVAudioEngineType) -> Bool {
        do {
            try bind(settings, in: engine)
        } catch {
            logger.warning("setCurrentDevice failed: \(String(describing: error), privacy: .public)")
            return false
        }
        if !settings.inputChannels.isEmpty, first.acceptsAudioInput {
            connectInput(settings.inputChannels, to: first, in: engine)
        }
        connectOutput(from: last, to: settings.outputChannels, in: engine)
        return true
    }

    func disconnect(in engine: AVAudioEngineType) {
        engine.disconnectMainMixerInput()
        engine.disconnectHardwareInput()
    }

    private func bind(_ settings: SessionAudioSettings.Audio, in engine: AVAudioEngineType) throws(AudioUnitGatewayError) {
        guard let outputUnit = engine.outputAudioUnit else { return }
        logging { try audioUnitGateway.setEnableIO(settings.isInputEnabled, bus: .input, on: outputUnit) }
        logging { try audioUnitGateway.setEnableIO(settings.isOutputEnabled, bus: .output, on: outputUnit) }
        try audioUnitGateway.setCurrentDevice(settings.deviceID, on: outputUnit)
    }

    private func connectInput(_ channels: [Int], to first: AVAudioUnit, in engine: AVAudioEngineType) {
        if let inputUnit = engine.inputAudioUnit {
            logging { try audioUnitGateway.setChannelMap(channels.map(Int32.init), bus: .input, on: inputUnit) }
        }
        let format = AVAudioFormat(
            standardFormatWithSampleRate: engine.hardwareOutputFormat.sampleRate,
            channels: AVAudioChannelCount(channels.count)
        )
        engine.connectHardwareInput(to: first, format: format)
    }

    private func connectOutput(from last: AVAudioUnit, to channels: [Int], in engine: AVAudioEngineType) {
        let format = AVAudioFormat(
            standardFormatWithSampleRate: engine.hardwareOutputFormat.sampleRate,
            channels: last.auAudioUnit.outputBusses[0].format.channelCount
        )
        engine.connectToMainMixer(last, format: format)

        guard !channels.isEmpty,
              let outputUnit = engine.outputAudioUnit,
              let physicalCount = audioUnitGateway.physicalChannelCount(of: outputUnit) else { return }
        var map = [Int32](repeating: -1, count: physicalCount)
        for (virtualIndex, physicalIndex) in channels.enumerated() where map.indices.contains(physicalIndex) {
            map[physicalIndex] = Int32(virtualIndex)
        }
        logging { try audioUnitGateway.setChannelMap(map, bus: .output, on: outputUnit) }
    }

    private func logging(_ work: () throws -> Void) {
        do {
            try work()
        } catch {
            logger.warning("\(String(describing: error), privacy: .public)")
        }
    }
}

private extension AVAudioUnit {
    var acceptsAudioInput: Bool {
        let type = audioComponentDescription.componentType
        return type == kAudioUnitType_Effect || type == kAudioUnitType_MusicEffect
    }
}
