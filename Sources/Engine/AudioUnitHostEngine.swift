//
//  AudioUnitHostEngine.swift
//  TinyAudioUnitHost
//
//  Created by Alex Shubin on 19.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

@preconcurrency import AVFoundation
@preconcurrency import CoreAudioKit

protocol AudioUnitHostEngineType: Observable, Sendable {
    func load(component: AudioUnitComponent) async -> LoadedAudioUnit?
    func setSelectedInputChannel(_ selection: SelectedChannel?) async
}

final actor AudioUnitHostEngine: AudioUnitHostEngineType {
    private let engine = AVAudioEngine()
    private var currentAVAudioUnit: AVAudioUnit?
    private var selectedInputChannel: SelectedChannel?

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
                channels: auInputChannelCount(for: selection)
            )
            setInputChannelMap(channelMap(for: selection))
            engine.connect(engine.inputNode, to: avAudioUnit, format: inputFormat)
        }

        let outputFormat = AVAudioFormat(
            standardFormatWithSampleRate: hardwareFormat.sampleRate,
            channels: 2
        )

        engine.connect(avAudioUnit, to: engine.mainMixerNode, format: outputFormat)
    }

    private func auInputChannelCount(for selection: SelectedChannel) -> UInt32 {
        switch selection {
        case .mono: return 1
        case .stereo: return 2
        }
    }

    private func channelMap(for selection: SelectedChannel) -> [Int32] {
        // AudioChannel ids are 1-indexed; CoreAudio channel maps are 0-indexed.
        switch selection {
        case .mono(let l): return [Int32(l.id) - 1]
        case .stereo(let l, let r): return [Int32(l.id) - 1, Int32(r.id) - 1]
        }
    }

    private func setInputChannelMap(_ map: [Int32]) {
        guard let inputAudioUnit = engine.inputNode.audioUnit else { return }
        var mutableMap = map
        let size = UInt32(MemoryLayout<Int32>.size * mutableMap.count)
        let status = AudioUnitSetProperty(
            inputAudioUnit,
            kAudioOutputUnitProperty_ChannelMap,
            kAudioUnitScope_Output,
            1,
            &mutableMap,
            size
        )
        assert(status == noErr, "Failed to set input channel map: \(status)")
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
