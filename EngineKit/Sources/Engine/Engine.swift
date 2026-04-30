//
//  Engine.swift
//  EngineKit
//
//  Created by Alex Shubin on 19.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AVFoundation
import Common
import StorageKit

public protocol EngineType: Sendable {
    func load(component: AudioUnitComponent) async -> LoadedAudioUnit?
    func reload() async
}

final actor Engine: EngineType {
    private let engine: AVAudioEngineType
    private let inputMixer: AVAudioMixerNode
    private let avAudioUnitFactory: AVAudioUnitFactoryType
    private let coreAudioGateway: CoreAudioGatewayType
    private let coreMidiManager: CoreMidiManagerType
    private let settingsStore: AudioSettingsStoreType
    private let aggregateDeviceManager: AggregateDeviceManagerType
    private var currentAVAudioUnit: AVAudioUnit?

    init(
        engine: AVAudioEngineType,
        inputMixer: AVAudioMixerNode,
        avAudioUnitFactory: AVAudioUnitFactoryType,
        coreAudioGateway: CoreAudioGatewayType,
        coreMidiManager: CoreMidiManagerType,
        settingsStore: AudioSettingsStoreType,
        aggregateDeviceManager: AggregateDeviceManagerType
    ) {
        self.engine = engine
        self.inputMixer = inputMixer
        self.avAudioUnitFactory = avAudioUnitFactory
        self.coreAudioGateway = coreAudioGateway
        self.coreMidiManager = coreMidiManager
        self.settingsStore = settingsStore
        self.aggregateDeviceManager = aggregateDeviceManager
        engine.attach(inputMixer)
    }

    func load(component: AudioUnitComponent) async -> LoadedAudioUnit? {
        engine.stop()
        disconnect()

        guard let loaded = await loadAudioUnit(component) else { return nil }

        await applyConnections()
        try? engine.start()

        return loaded
    }

    func reload() async {
        engine.stop()
        disconnect()
        await applyConnections()
        try? engine.start()
    }

    private func applyConnections() async {
        let settings = await settingsStore.current()
        let target = await aggregateDeviceManager.resolveTarget()

        bindDevice(target)
        if let frames = settings.bufferSize, let deviceID = target?.device.id {
            coreAudioGateway.setBufferSize(frames, deviceID: deviceID)
        }

        guard let avAudioUnit = currentAVAudioUnit else { return }

        if let input = settings.input.selectedChannel, avAudioUnit.acceptsAudioInput {
            connectInputs(avAudioUnit: avAudioUnit, channels: input, hardwareOffset: target?.inputOffset ?? 0)
        }
        if let output = settings.output.selectedChannel {
            connectOutputs(avAudioUnit: avAudioUnit, channels: output, hardwareOffset: target?.outputOffset ?? 0)
        }
    }

    private func bindDevice(_ target: TargetAudioDevice?) {
        guard let target, let audioUnit = engine.outputNode.audioUnit else { return }
        coreAudioGateway.setEnableIO(target.inputSource != nil, scope: kAudioUnitScope_Input, element: 1, on: audioUnit)
        coreAudioGateway.setEnableIO(target.outputSource != nil, scope: kAudioUnitScope_Output, element: 0, on: audioUnit)
        coreAudioGateway.setCurrentDevice(target.device.id, on: audioUnit)
    }

    private func connectInputs(avAudioUnit: AVAudioUnit, channels: SelectedChannel, hardwareOffset: Int) {
        let hardwareFormat = engine.outputNode.outputFormat(forBus: 0)
        let userFormat = AVAudioFormat(
            standardFormatWithSampleRate: hardwareFormat.sampleRate,
            channels: channels.channelCount
        )
        let auInputFormat = AVAudioFormat(
            standardFormatWithSampleRate: hardwareFormat.sampleRate,
            channels: avAudioUnit.auAudioUnit.inputBusses[0].format.channelCount
        )

        if let inputAudioUnit = engine.inputNode.audioUnit {
            let map: [Int32] = channels.channels.map { Int32(hardwareOffset) + Int32($0.id) - 1 }
            coreAudioGateway.setChannelMap(map, element: 1, on: inputAudioUnit)
        }

        engine.connect(engine.inputNode, to: inputMixer, format: userFormat)
        engine.connect(inputMixer, to: avAudioUnit, format: auInputFormat)
    }

    private func connectOutputs(avAudioUnit: AVAudioUnit, channels: SelectedChannel, hardwareOffset: Int) {
        let hardwareFormat = engine.outputNode.outputFormat(forBus: 0)
        let outputFormat = AVAudioFormat(
            standardFormatWithSampleRate: hardwareFormat.sampleRate,
            channels: avAudioUnit.auAudioUnit.outputBusses[0].format.channelCount
        )

        engine.connect(avAudioUnit, to: engine.mainMixerNode, format: outputFormat)

        if let outputAudioUnit = engine.outputNode.audioUnit, let physicalCount = coreAudioGateway.physicalChannelCount(of: outputAudioUnit) {
            var map = [Int32](repeating: -1, count: physicalCount)
            for (virtualIdx, channel) in channels.channels.enumerated() {
                let physicalIdx = hardwareOffset + Int(channel.id) - 1
                guard physicalIdx >= 0, physicalIdx < physicalCount else { continue }
                map[physicalIdx] = Int32(virtualIdx)
            }
            coreAudioGateway.setChannelMap(map, element: 0, on: outputAudioUnit)
        }
    }

    private func disconnect() {
        engine.disconnectNodeInput(engine.mainMixerNode)
        engine.disconnectNodeOutput(inputMixer)
        engine.disconnectNodeOutput(engine.inputNode)
    }

    private func loadAudioUnit(_ component: AudioUnitComponent) async -> LoadedAudioUnit? {
        coreMidiManager.teardownMIDI()
        unloadAudioUnit()
        do {
            let avAudioUnit = try await avAudioUnitFactory.instantiate(
                with: component.componentDescription,
                options: .loadOutOfProcess
            )

            currentAVAudioUnit = avAudioUnit
            engine.attach(avAudioUnit)

            coreMidiManager.setupMIDI(for: avAudioUnit.auAudioUnit)

            return LoadedAudioUnit(component: component, auAudioUnit: avAudioUnit.auAudioUnit)
        } catch {
            return nil
        }
    }

    private func unloadAudioUnit() {
        guard let node = currentAVAudioUnit else { return }
        engine.detach(node)
        currentAVAudioUnit = nil
    }
}

fileprivate extension AVAudioUnit {
    var acceptsAudioInput: Bool {
        let type = audioComponentDescription.componentType
        return type == kAudioUnitType_Effect || type == kAudioUnitType_MusicEffect
    }
}

fileprivate extension SelectedChannel {
    var channelCount: UInt32 {
        switch self {
        case .mono: return 1
        case .stereo: return 2
        }
    }
}
