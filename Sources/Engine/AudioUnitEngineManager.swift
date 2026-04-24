//
//  AudioUnitEngineManager.swift
//  TinyAudioUnitHost
//
//  Created by Alex Shubin on 19.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

@preconcurrency import AVFoundation
@preconcurrency import CoreAudioKit

protocol AudioUnitEngineManagerType: Observable, Sendable {
    func load(component: AudioUnitComponent) async -> LoadedAudioUnit?
    func setSelectedInputChannel(_ selection: SelectedChannel?) async
    func setSelectedOutputChannel(_ selection: SelectedChannel?) async
}

final actor AudioUnitEngineManager: AudioUnitEngineManagerType {
    private let engine = AVAudioEngine()
    private var currentAVAudioUnit: AVAudioUnit?
    private var selectedInputChannel: SelectedChannel?
    private var selectedOutputChannel: SelectedChannel?

    private let coreMidiManager: CoreMidiManagerType

    init(
        coreMidiManager: CoreMidiManagerType
    ) {
        self.coreMidiManager = coreMidiManager
    }

    func load(component: AudioUnitComponent) async -> LoadedAudioUnit? {
        coreMidiManager.teardownMIDI()
        removeCurrentNode()

        do {
            let avAudioUnit = try await AVAudioUnit.instantiate(
                with: component.componentDescription,
                options: .loadOutOfProcess
            )

            currentAVAudioUnit = avAudioUnit
            engine.attach(avAudioUnit)

            try connectGraph(for: avAudioUnit)
            try engine.start()

            coreMidiManager.setupMIDI(for: avAudioUnit.auAudioUnit)

            return LoadedAudioUnit(component: component) {
                await withCheckedContinuation { continuation in
                    avAudioUnit.auAudioUnit.requestViewController { continuation.resume(returning: $0) }
                }
            }
        } catch {
            return nil
        }
    }

    func setSelectedInputChannel(_ selection: SelectedChannel?) async {
        selectedInputChannel = selection
        rebuildGraph()
    }

    func setSelectedOutputChannel(_ selection: SelectedChannel?) async {
        selectedOutputChannel = selection
        rebuildGraph()
    }

    private func rebuildGraph() {
        guard let avAudioUnit = currentAVAudioUnit else { return }
        engine.stop()
        engine.disconnectNodeInput(engine.mainMixerNode)
        engine.disconnectNodeOutput(engine.inputNode)
        do {
            try connectGraph(for: avAudioUnit)
            try engine.start()
        } catch {
            return
        }
    }

    private func connectGraph(for avAudioUnit: AVAudioUnit) throws {
        let hardwareFormat = engine.outputNode.outputFormat(forBus: 0)

        if acceptsAudioInput(avAudioUnit), let selection = selectedInputChannel {
            let inputFormat = AVAudioFormat(
                standardFormatWithSampleRate: hardwareFormat.sampleRate,
                channels: channelCount(for: selection)
            )
            setInputChannelMap(for: selection)
            engine.connect(engine.inputNode, to: avAudioUnit, format: inputFormat)
        }

        let outputFormat = AVAudioFormat(
            standardFormatWithSampleRate: hardwareFormat.sampleRate,
            channels: 2
        )

        engine.connect(avAudioUnit, to: engine.mainMixerNode, format: outputFormat)

        if let selection = selectedOutputChannel {
            setOutputChannelMap(for: selection)
        }
    }

    private func channelCount(for selection: SelectedChannel) -> UInt32 {
        switch selection {
        case .mono: return 1
        case .stereo: return 2
        }
    }

    private func setInputChannelMap(for selection: SelectedChannel) {
        guard let inputAudioUnit = engine.inputNode.audioUnit else { return }
        // Input HAL: length = virtual channels, map[virtual] = physical (0-indexed).
        let map: [Int32] = selection.channels.map { Int32($0.id) - 1 }
        setChannelMap(map, on: inputAudioUnit, element: 1)
    }

    private func setOutputChannelMap(for selection: SelectedChannel) {
        guard let outputAudioUnit = engine.outputNode.audioUnit,
              let physicalCount = physicalChannelCount(of: outputAudioUnit)
        else { return }
        // Output HAL: length = physical channels, map[physical] = virtual (0-indexed) or -1.
        var map = [Int32](repeating: -1, count: physicalCount)
        for (virtualIdx, channel) in selection.channels.enumerated() {
            let physicalIdx = Int(channel.id) - 1
            guard physicalIdx >= 0, physicalIdx < physicalCount else { continue }
            map[physicalIdx] = Int32(virtualIdx)
        }
        setChannelMap(map, on: outputAudioUnit, element: 0)
    }

    private func physicalChannelCount(of audioUnit: AudioUnit) -> Int? {
        var streamFormat = AudioStreamBasicDescription()
        var size = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        let status = AudioUnitGetProperty(
            audioUnit,
            kAudioUnitProperty_StreamFormat,
            kAudioUnitScope_Output,
            0,
            &streamFormat,
            &size
        )
        guard status == noErr else { return nil }
        return Int(streamFormat.mChannelsPerFrame)
    }

    private func setChannelMap(_ map: [Int32], on audioUnit: AudioUnit, element: AudioUnitElement) {
        var mutableMap = map
        let size = UInt32(MemoryLayout<Int32>.size * mutableMap.count)
        let status = AudioUnitSetProperty(
            audioUnit,
            kAudioOutputUnitProperty_ChannelMap,
            kAudioUnitScope_Output,
            element,
            &mutableMap,
            size
        )
        assert(status == noErr, "Failed to set channel map: \(status)")
    }

    private func removeCurrentNode() {
        if let node = currentAVAudioUnit {
            engine.stop()
            engine.disconnectNodeInput(engine.mainMixerNode)
            engine.disconnectNodeOutput(engine.inputNode)
            engine.detach(node)
            currentAVAudioUnit = nil
        }
    }

    private func acceptsAudioInput(_ avAudioUnit: AVAudioUnit) -> Bool {
        let type = avAudioUnit.audioComponentDescription.componentType
        return type == kAudioUnitType_Effect || type == kAudioUnitType_MusicEffect
    }
}
