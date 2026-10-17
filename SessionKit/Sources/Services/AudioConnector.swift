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

/// Connects the channel strip's ends to the audio device: device binding, I/O, channel maps, input and output.
protocol AudioConnectorType: Sendable {
    func connect(input: AVAudioNode?, output: AVAudioUnit, to settings: SessionHardwareSettings.Audio, in engine: AVAudioEngineType) -> Bool
    func disconnect(in engine: AVAudioEngineType)
}

struct AudioConnector: AudioConnectorType {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "AudioConnector")

    let audioUnitGateway: AudioUnitGatewayType

    func connect(input: AVAudioNode?, output: AVAudioUnit, to settings: SessionHardwareSettings.Audio, in engine: AVAudioEngineType) -> Bool {
        do {
            try bind(settings, in: engine)
        } catch {
            logger.warning("setCurrentDevice failed: \(String(describing: error), privacy: .public)")
            return false
        }
        if let input {
            connectInput(settings.inputChannels, to: input, in: engine)
        }
        connectOutput(from: output, to: settings.outputChannels, offset: settings.outputChannelOffset, in: engine)
        return true
    }

    func disconnect(in engine: AVAudioEngineType) {
        engine.disconnectMainMixerInput()
        engine.disconnectHardwareInput()
    }

    private func bind(_ settings: SessionHardwareSettings.Audio, in engine: AVAudioEngineType) throws(AudioUnitGatewayError) {
        guard let outputUnit = engine.outputAudioUnit else { return }
        logging { try audioUnitGateway.setEnableIO(settings.inputDevice != nil, bus: .input, on: outputUnit) }
        logging { try audioUnitGateway.setEnableIO(settings.outputDevice != nil, bus: .output, on: outputUnit) }
        try audioUnitGateway.setCurrentDevice(settings.deviceID, on: outputUnit)
    }

    private func connectInput(_ channels: [UInt32], to input: AVAudioNode, in engine: AVAudioEngineType) {
        if let inputUnit = engine.inputAudioUnit {
            let map = channels.map { Int32($0) - 1 }
            logging { try audioUnitGateway.setChannelMap(map, bus: .input, on: inputUnit) }
        }
        let format = AVAudioFormat(
            standardFormatWithSampleRate: engine.hardwareOutputFormat.sampleRate,
            channels: AVAudioChannelCount(channels.count)
        )
        engine.connectHardwareInput(to: input, format: format)
    }

    private func connectOutput(from output: AVAudioUnit, to channels: [UInt32], offset: Int, in engine: AVAudioEngineType) {
        let format = AVAudioFormat(
            standardFormatWithSampleRate: engine.hardwareOutputFormat.sampleRate,
            channels: output.auAudioUnit.outputBusses[0].format.channelCount
        )
        engine.connectToMainMixer(output, format: format)

        guard !channels.isEmpty,
              let outputUnit = engine.outputAudioUnit,
              let physicalCount = audioUnitGateway.physicalChannelCount(of: outputUnit) else { return }
        var map = [Int32](repeating: -1, count: physicalCount)
        for (virtualIndex, channel) in channels.enumerated() {
            let physicalIndex = offset + Int(channel) - 1
            guard map.indices.contains(physicalIndex) else { continue }
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

private extension SessionHardwareSettings.Audio {
    /// Output position in the aggregate's physical channel layout.
    /// `AggregateDeviceFactory` lists sub-devices as [input, output], so output's channels start
    /// after the input device's output channels in the combined layout.
    var outputChannelOffset: Int {
        guard let inputDevice, let outputDevice, inputDevice.id != outputDevice.id else { return 0 }
        return inputDevice.outputChannelCount
    }
}
