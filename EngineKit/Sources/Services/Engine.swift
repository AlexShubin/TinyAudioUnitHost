//
//  Engine.swift
//  EngineKit
//
//  Created by Alex Shubin on 19.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioSettingsKit
import AudioToolboxGatewayKit
import AudioUnitsKit
import AVFoundation
import OSLog

public enum EngineLoadError: Error, Sendable, Equatable {
    case audioUnitInstantiationFailed
}

public protocol EngineType: Sendable {
    func load(component: AudioUnitComponent, state: Data?, at position: Int) async throws(EngineLoadError) -> LoadedAudioUnit
    func unload(at position: Int) async
    func reload() async
}

final actor Engine: EngineType {
    private struct Node {
        let avAudioUnit: AVAudioUnit
        let audioUnit: LoadedAudioUnit
    }

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "Engine")

    private let engine: AVAudioEngineType
    private let inputMixer: AVAudioMixerNode
    private let avAudioUnitFactory: AVAudioUnitFactoryType
    private let audioUnitGateway: AudioUnitGatewayType
    private let midiManager: MidiManagerType
    private let audioSettings: AudioSettingsModelType
    private var chain: [Int: Node] = [:]

    init(
        engine: AVAudioEngineType,
        inputMixer: AVAudioMixerNode,
        avAudioUnitFactory: AVAudioUnitFactoryType,
        audioUnitGateway: AudioUnitGatewayType,
        midiManager: MidiManagerType,
        audioSettings: AudioSettingsModelType
    ) {
        self.engine = engine
        self.inputMixer = inputMixer
        self.avAudioUnitFactory = avAudioUnitFactory
        self.audioUnitGateway = audioUnitGateway
        self.midiManager = midiManager
        self.audioSettings = audioSettings
        engine.attach(inputMixer)
    }

    func load(component: AudioUnitComponent, state: Data?, at position: Int) async throws(EngineLoadError) -> LoadedAudioUnit {
        await tearDown()
        detachNode(at: position)

        let node: Node
        do {
            node = try await instantiate(component)
        } catch {
            await rebuild()
            throw error
        }
        if let state { node.audioUnit.fullState = state }
        detachNode(at: position)
        chain[position] = node
        await rebuild()
        return node.audioUnit
    }

    func unload(at position: Int) async {
        await tearDown()
        detachNode(at: position)
        await rebuild()
    }

    func reload() async {
        guard !chain.isEmpty else { return }
        engine.stop()
        disconnect()
        await connectAndStart()
    }

    private var orderedNodes: [Node] {
        chain.sorted { $0.key < $1.key }.map(\.value)
    }

    private func tearDown() async {
        engine.stop()
        disconnect()
        await midiManager.teardownMIDI()
    }

    private func rebuild() async {
        await tearDown()
        guard let first = orderedNodes.first else { return }
        await connectAndStart()
        await midiManager.setupMIDI(for: first.audioUnit)
    }

    private func connectAndStart() async {
        guard await audioSettings.setup == .met,
              let device = await audioSettings.targetDevice else { return }
        let settings = await audioSettings.settings
        do {
            try bindDevice(device, settings: settings)
        } catch {
            logger.warning("setCurrentDevice failed: \(String(describing: error), privacy: .public)")
            return
        }
        applyConnections(settings: settings)
        logging { try engine.start() }
    }

    private func applyConnections(settings: AudioSettings) {
        let nodes = orderedNodes.map(\.avAudioUnit)
        guard let first = nodes.first, let last = nodes.last else { return }

        if let input = settings.inputChannel, first.acceptsAudioInput {
            connectInputs(avAudioUnit: first, channels: input)
        }
        for (source, destination) in zip(nodes, nodes.dropFirst()) {
            connect(source, to: destination)
        }
        if let output = settings.outputChannel {
            connectOutputs(avAudioUnit: last, channels: output, hardwareOffset: settings.outputOffset)
        }
    }

    private func bindDevice(_ device: AudioDevice, settings: AudioSettings) throws(AudioUnitGatewayError) {
        guard let audioUnit = engine.outputAudioUnit else { return }
        logging { try audioUnitGateway.setEnableIO(settings.inputDevice != nil, bus: .input, on: audioUnit) }
        logging { try audioUnitGateway.setEnableIO(settings.outputDevice != nil, bus: .output, on: audioUnit) }
        try audioUnitGateway.setCurrentDevice(device.id, on: audioUnit)
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
            logging { try audioUnitGateway.setChannelMap(map, bus: .input, on: inputAudioUnit) }
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

        if let outputAudioUnit = engine.outputAudioUnit, let physicalCount = audioUnitGateway.physicalChannelCount(of: outputAudioUnit) {
            var map = [Int32](repeating: -1, count: physicalCount)
            for (virtualIdx, channel) in channels.channels.enumerated() {
                let physicalIdx = hardwareOffset + Int(channel.id) - 1
                guard physicalIdx >= 0, physicalIdx < physicalCount else { continue }
                map[physicalIdx] = Int32(virtualIdx)
            }
            logging { try audioUnitGateway.setChannelMap(map, bus: .output, on: outputAudioUnit) }
        }
    }

    private func disconnect() {
        engine.disconnectMainMixerInput()
        engine.disconnectNodeOutput(inputMixer)
        engine.disconnectHardwareInput()
    }

    private func connect(_ source: AVAudioUnit, to destination: AVAudioUnit) {
        let format = AVAudioFormat(
            standardFormatWithSampleRate: engine.hardwareOutputFormat.sampleRate,
            channels: source.auAudioUnit.outputBusses[0].format.channelCount
        )
        engine.connect(source, to: destination, format: format)
    }

    private func instantiate(_ component: AudioUnitComponent) async throws(EngineLoadError) -> Node {
        do {
            let avAudioUnit = try await avAudioUnitFactory.instantiate(
                with: component.componentDescription,
                options: .loadOutOfProcess
            )
            engine.attach(avAudioUnit)
            return Node(avAudioUnit: avAudioUnit, audioUnit: LoadedAudioUnit(avAudioUnit.auAudioUnit))
        } catch {
            logger.warning("AU instantiation failed: \(String(describing: error), privacy: .public)")
            throw EngineLoadError.audioUnitInstantiationFailed
        }
    }

    private func detachNode(at position: Int) {
        guard let node = chain.removeValue(forKey: position) else { return }
        engine.detach(node.avAudioUnit)
    }

    private func logging(_ work: () throws -> Void) {
        do {
            try work()
        } catch {
            logger.warning("\(String(describing: error), privacy: .public)")
        }
    }
}

private extension AudioUnitComponent {
    var componentDescription: AudioComponentDescription {
        AudioComponentDescription(
            componentType: id.type,
            componentSubType: id.subType,
            componentManufacturer: id.manufacturer,
            componentFlags: 0,
            componentFlagsMask: 0
        )
    }
}

fileprivate extension AVAudioUnit {
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
