//
//  Engine.swift
//  EngineKit
//
//  Created by Alex Shubin on 19.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioSettingsKit
import AudioUnitsKit
import AVFoundation
import OSLog

public enum EngineLoadError: Error, Sendable, Equatable {
    case audioUnitInstantiationFailed
    case deviceUnavailable
}

public protocol EngineType: Sendable {
    func load(component: AudioUnitComponent, state: Data?) async throws -> LoadedAudioUnit
    func reload() async throws
}

final actor Engine: EngineType {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "Engine")

    private let engine: AVAudioEngineType
    private let inputMixer: AVAudioMixerNode
    private let avAudioUnitFactory: AVAudioUnitFactoryType
    private let coreAudioGateway: CoreAudioGatewayType
    private let coreMidiManager: CoreMidiManagerType
    private let targetSettingsProvider: TargetSettingsProviderType
    private var currentAVAudioUnit: AVAudioUnit?

    init(
        engine: AVAudioEngineType,
        inputMixer: AVAudioMixerNode,
        avAudioUnitFactory: AVAudioUnitFactoryType,
        coreAudioGateway: CoreAudioGatewayType,
        coreMidiManager: CoreMidiManagerType,
        targetSettingsProvider: TargetSettingsProviderType
    ) {
        self.engine = engine
        self.inputMixer = inputMixer
        self.avAudioUnitFactory = avAudioUnitFactory
        self.coreAudioGateway = coreAudioGateway
        self.coreMidiManager = coreMidiManager
        self.targetSettingsProvider = targetSettingsProvider
        engine.attach(inputMixer)
    }

    func load(component: AudioUnitComponent, state: Data?) async throws -> LoadedAudioUnit {
        engine.stop()
        disconnect()

        let loaded = try await loadAudioUnit(component)
        if let state { loaded.audioUnit.fullState = state }

        do {
            try await applyConnections()
        } catch {
            unloadAudioUnit()
            await coreMidiManager.teardownMIDI()
            throw error
        }
        logging { try engine.start() }

        return loaded
    }

    func reload() async throws {
        engine.stop()
        disconnect()
        try await applyConnections()
        logging { try engine.start() }
    }

    private func applyConnections() async throws {
        guard let target = await targetSettingsProvider.resolveTarget() else { return }
        let settings = target.settings

        try bindDevice(target)
        if let rate = settings.sampleRate {
            logging { try coreAudioGateway.setSampleRate(rate, deviceID: target.device.id) }
        }
        if let frames = settings.bufferSize {
            logging { try coreAudioGateway.setBufferSize(frames, deviceID: target.device.id) }
        }

        guard let avAudioUnit = currentAVAudioUnit else { return }

        if let input = settings.inputChannel, avAudioUnit.acceptsAudioInput {
            connectInputs(avAudioUnit: avAudioUnit, channels: input)
        }
        if let output = settings.outputChannel {
            connectOutputs(avAudioUnit: avAudioUnit, channels: output, hardwareOffset: target.outputOffset)
        }
    }

    private func bindDevice(_ target: TargetSettings) throws {
        guard let audioUnit = engine.outputAudioUnit else { return }
        logging { try coreAudioGateway.setEnableIO(target.settings.inputDevice != nil, scope: kAudioUnitScope_Input, element: 1, on: audioUnit) }
        logging { try coreAudioGateway.setEnableIO(target.settings.outputDevice != nil, scope: kAudioUnitScope_Output, element: 0, on: audioUnit) }
        do {
            try coreAudioGateway.setCurrentDevice(target.device.id, on: audioUnit)
        } catch {
            logger.warning("setCurrentDevice failed: \(String(describing: error), privacy: .public)")
            throw EngineLoadError.deviceUnavailable
        }
    }

    private func connectInputs(avAudioUnit: AVAudioUnit, channels: SelectedChannel) {
        let hardwareFormat = engine.hardwareOutputFormat
        let userFormat = AVAudioFormat(
            standardFormatWithSampleRate: hardwareFormat.sampleRate,
            channels: UInt32(channels.channels.count)
        )
        let auInputFormat = AVAudioFormat(
            standardFormatWithSampleRate: hardwareFormat.sampleRate,
            channels: avAudioUnit.auAudioUnit.inputBusses[0].format.channelCount
        )

        if let inputAudioUnit = engine.inputAudioUnit {
            let map: [Int32] = channels.channels.map { Int32($0.id) - 1 }
            logging { try coreAudioGateway.setChannelMap(map, element: 1, on: inputAudioUnit) }
        }

        engine.connectHardwareInput(to: inputMixer, format: userFormat)
        engine.connect(inputMixer, to: avAudioUnit, format: auInputFormat)
    }

    private func connectOutputs(avAudioUnit: AVAudioUnit, channels: SelectedChannel, hardwareOffset: Int) {
        let hardwareFormat = engine.hardwareOutputFormat
        let outputFormat = AVAudioFormat(
            standardFormatWithSampleRate: hardwareFormat.sampleRate,
            channels: avAudioUnit.auAudioUnit.outputBusses[0].format.channelCount
        )

        engine.connectToMainMixer(avAudioUnit, format: outputFormat)

        if let outputAudioUnit = engine.outputAudioUnit, let physicalCount = coreAudioGateway.physicalChannelCount(of: outputAudioUnit) {
            var map = [Int32](repeating: -1, count: physicalCount)
            for (virtualIdx, channel) in channels.channels.enumerated() {
                let physicalIdx = hardwareOffset + Int(channel.id) - 1
                guard physicalIdx >= 0, physicalIdx < physicalCount else { continue }
                map[physicalIdx] = Int32(virtualIdx)
            }
            logging { try coreAudioGateway.setChannelMap(map, element: 0, on: outputAudioUnit) }
        }
    }

    private func disconnect() {
        engine.disconnectMainMixerInput()
        engine.disconnectNodeOutput(inputMixer)
        engine.disconnectHardwareInput()
    }

    private func loadAudioUnit(_ component: AudioUnitComponent) async throws -> LoadedAudioUnit {
        await coreMidiManager.teardownMIDI()
        unloadAudioUnit()
        do {
            let avAudioUnit = try await avAudioUnitFactory.instantiate(
                with: component.componentDescription,
                options: .loadOutOfProcess
            )

            currentAVAudioUnit = avAudioUnit
            engine.attach(avAudioUnit)

            await coreMidiManager.setupMIDI(for: avAudioUnit.auAudioUnit)

            return LoadedAudioUnit(component: component, audioUnit: AUAudioUnitWrapper(avAudioUnit.auAudioUnit))
        } catch {
            logger.warning("AU instantiation failed: \(String(describing: error), privacy: .public)")
            throw EngineLoadError.audioUnitInstantiationFailed
        }
    }

    private func unloadAudioUnit() {
        guard let node = currentAVAudioUnit else { return }
        engine.detach(node)
        currentAVAudioUnit = nil
    }

    private func logging(_ work: () throws -> Void) {
        do {
            try work()
        } catch {
            logger.warning("\(String(describing: error), privacy: .public)")
        }
    }
}

fileprivate extension AVAudioUnit {
    var acceptsAudioInput: Bool {
        let type = audioComponentDescription.componentType
        return type == kAudioUnitType_Effect || type == kAudioUnitType_MusicEffect
    }
}

private extension TargetSettings {
    /// Output position in the aggregate's physical channel layout.
    /// Sub-devices are listed [input, output], so output's channels start
    /// after the input device's output channels in the combined layout.
    var outputOffset: Int {
        guard let input = settings.inputDevice,
              let output = settings.outputDevice,
              input.id != output.id else { return 0 }
        return input.outputChannels.count
    }
}
