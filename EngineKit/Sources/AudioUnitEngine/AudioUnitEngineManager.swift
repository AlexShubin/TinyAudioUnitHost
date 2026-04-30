//
//  AudioUnitEngineManager.swift
//  EngineKit
//
//  Created by Alex Shubin on 19.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

@preconcurrency import CoreAudioKit
import Common
import StorageKit

public protocol AudioUnitEngineManagerType: Sendable {
    func load(component: AudioUnitComponent) async -> LoadedAudioUnit?
    func reload() async
}

final actor AudioUnitEngineManager: AudioUnitEngineManagerType {
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
        coreMidiManager.teardownMIDI()
        engine.stop()
        disconnect()
        unloadAudioUnit()

        guard let loaded = await loadAudioUnit(component) else { return nil }

        await applyConnections()
        if let avAudioUnit = currentAVAudioUnit {
            coreMidiManager.setupMIDI(for: avAudioUnit.auAudioUnit)
        }
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

        if let input = settings.input.selectedChannel {
            connectInputs(channels: input, hardwareOffset: target?.inputOffset ?? 0)
        }
        if let output = settings.output.selectedChannel {
            connectOutputs(channels: output, hardwareOffset: target?.outputOffset ?? 0)
        }
    }

    private func bindDevice(_ target: TargetAudioDevice?) {
        guard let target, let audioUnit = engine.outputNode.audioUnit else { return }
        coreAudioGateway.setEnableIO(target.inputSource != nil, scope: kAudioUnitScope_Input, element: 1, on: audioUnit)
        coreAudioGateway.setEnableIO(target.outputSource != nil, scope: kAudioUnitScope_Output, element: 0, on: audioUnit)
        coreAudioGateway.setCurrentDevice(target.device.id, on: audioUnit)
    }

    private func connectInputs(channels: SelectedChannel, hardwareOffset: Int) {
        guard let avAudioUnit = currentAVAudioUnit, avAudioUnit.acceptsAudioInput else { return }
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
            setInputChannelMap(on: inputAudioUnit, selection: channels, hardwareOffset: hardwareOffset)
        }
        engine.connect(engine.inputNode, to: inputMixer, format: userFormat)
        engine.connect(inputMixer, to: avAudioUnit, format: auInputFormat)
    }

    private func connectOutputs(channels: SelectedChannel, hardwareOffset: Int) {
        guard let avAudioUnit = currentAVAudioUnit else { return }
        let hardwareFormat = engine.outputNode.outputFormat(forBus: 0)
        let outputFormat = AVAudioFormat(
            standardFormatWithSampleRate: hardwareFormat.sampleRate,
            channels: avAudioUnit.auAudioUnit.outputBusses[0].format.channelCount
        )
        engine.connect(avAudioUnit, to: engine.mainMixerNode, format: outputFormat)
        if let outputAudioUnit = engine.outputNode.audioUnit {
            setOutputChannelMap(on: outputAudioUnit, selection: channels, hardwareOffset: hardwareOffset)
        }
    }

    private func setInputChannelMap(on audioUnit: AudioUnit, selection: SelectedChannel, hardwareOffset: Int) {
        // Input HAL: length = virtual channels, map[virtual] = physical (0-indexed).
        let map: [Int32] = selection.channels.map { Int32(hardwareOffset) + Int32($0.id) - 1 }
        coreAudioGateway.setChannelMap(map, element: 1, on: audioUnit)
    }

    private func setOutputChannelMap(on audioUnit: AudioUnit, selection: SelectedChannel, hardwareOffset: Int) {
        guard let physicalCount = coreAudioGateway.physicalChannelCount(of: audioUnit) else { return }
        // Output HAL: length = physical channels, map[physical] = virtual (0-indexed) or -1.
        var map = [Int32](repeating: -1, count: physicalCount)
        for (virtualIdx, channel) in selection.channels.enumerated() {
            let physicalIdx = hardwareOffset + Int(channel.id) - 1
            guard physicalIdx >= 0, physicalIdx < physicalCount else { continue }
            map[physicalIdx] = Int32(virtualIdx)
        }
        coreAudioGateway.setChannelMap(map, element: 0, on: audioUnit)
    }

    private func disconnect() {
        engine.disconnectNodeInput(engine.mainMixerNode)
        engine.disconnectNodeOutput(inputMixer)
        engine.disconnectNodeOutput(engine.inputNode)
    }

    private func loadAudioUnit(_ component: AudioUnitComponent) async -> LoadedAudioUnit? {
        guard component.componentDescription.componentType != kAudioUnitType_Output else {
            return nil
        }
        do {
            let avAudioUnit = try await avAudioUnitFactory.instantiate(
                with: component.componentDescription,
                options: .loadOutOfProcess
            )

            currentAVAudioUnit = avAudioUnit
            engine.attach(avAudioUnit)

            return LoadedAudioUnit(component: component) {
                await withCheckedContinuation { continuation in
                    avAudioUnit.auAudioUnit.requestViewController { continuation.resume(returning: $0) }
                }
            }
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
