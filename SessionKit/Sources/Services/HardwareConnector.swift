//
//  HardwareConnector.swift
//  SessionKit
//
//  Created by Alex Shubin on 14.10.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioSettingsKit
import AudioToolboxGatewayKit
import AVFoundation
import OSLog

protocol HardwareConnectorType: Sendable {
    func connect(first: AVAudioUnit, last: AVAudioUnit, in engine: AVAudioEngineType) async -> Bool
    func disconnect(in engine: AVAudioEngineType)
}

struct HardwareConnector: HardwareConnectorType {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "HardwareConnector")

    let audioUnitGateway: AudioUnitGatewayType
    let audioSettings: AudioSettingsModelType

    func connect(first: AVAudioUnit, last: AVAudioUnit, in engine: AVAudioEngineType) async -> Bool {
        guard await audioSettings.setup == .met,
              let device = await audioSettings.targetDevice else { return false }
        let settings = await audioSettings.settings
        do {
            try bind(device, settings: settings, in: engine)
        } catch {
            logger.warning("setCurrentDevice failed: \(String(describing: error), privacy: .public)")
            return false
        }
        if let inputChannel = settings.inputChannel, first.acceptsAudioInput {
            connectInput(inputChannel, to: first, in: engine)
        }
        connectOutput(from: last, to: settings.outputChannel, hardwareOffset: settings.outputOffset, in: engine)
        return true
    }

    func disconnect(in engine: AVAudioEngineType) {
        engine.disconnectMainMixerInput()
        engine.disconnectHardwareInput()
    }

    private func bind(_ device: AudioDevice, settings: AudioSettings, in engine: AVAudioEngineType) throws(AudioUnitGatewayError) {
        guard let outputUnit = engine.outputAudioUnit else { return }
        logging { try audioUnitGateway.setEnableIO(settings.inputDevice != nil, bus: .input, on: outputUnit) }
        logging { try audioUnitGateway.setEnableIO(settings.outputDevice != nil, bus: .output, on: outputUnit) }
        try audioUnitGateway.setCurrentDevice(device.id, on: outputUnit)
    }

    private func connectInput(_ channels: SelectedChannel, to first: AVAudioUnit, in engine: AVAudioEngineType) {
        if let inputUnit = engine.inputAudioUnit {
            let map: [Int32] = channels.channels.map { Int32($0.id) - 1 }
            logging { try audioUnitGateway.setChannelMap(map, bus: .input, on: inputUnit) }
        }
        let format = AVAudioFormat(
            standardFormatWithSampleRate: engine.hardwareOutputFormat.sampleRate,
            channels: AVAudioChannelCount(channels.channels.count)
        )
        engine.connectHardwareInput(to: first, format: format)
    }

    private func connectOutput(from last: AVAudioUnit, to channels: SelectedChannel?, hardwareOffset: Int, in engine: AVAudioEngineType) {
        let format = AVAudioFormat(
            standardFormatWithSampleRate: engine.hardwareOutputFormat.sampleRate,
            channels: last.auAudioUnit.outputBusses[0].format.channelCount
        )
        engine.connectToMainMixer(last, format: format)

        guard let channels,
              let outputUnit = engine.outputAudioUnit,
              let physicalCount = audioUnitGateway.physicalChannelCount(of: outputUnit) else { return }
        var map = [Int32](repeating: -1, count: physicalCount)
        for (virtualIdx, channel) in channels.channels.enumerated() {
            let physicalIdx = hardwareOffset + Int(channel.id) - 1
            guard physicalIdx >= 0, physicalIdx < physicalCount else { continue }
            map[physicalIdx] = Int32(virtualIdx)
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

private extension AudioSettings {
    /// Output position in the aggregate's physical channel layout.
    /// Sub-devices are listed [input, output], so output's channels start
    /// after the input device's output channels in the combined layout.
    var outputOffset: Int {
        guard let input = inputDevice,
              let output = outputDevice,
              input.id != output.id else { return 0 }
        return input.outputChannels.count
    }
}
