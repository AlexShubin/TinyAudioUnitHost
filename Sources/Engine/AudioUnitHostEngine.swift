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
}

final actor AudioUnitHostEngine: AudioUnitHostEngineType {
    private let engine = AVAudioEngine()
    private var currentAVAudioUnit: AVAudioUnit?

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

            let hardwareFormat = engine.outputNode.outputFormat(forBus: 0)
            let stereoFormat = AVAudioFormat(
                standardFormatWithSampleRate: hardwareFormat.sampleRate,
                channels: 2
            )

            engine.connect(engine.inputNode, to: avAudioUnit, format: stereoFormat)
            engine.connect(avAudioUnit, to: engine.mainMixerNode, format: stereoFormat)
            engine.connect(engine.mainMixerNode, to: engine.outputNode, format: hardwareFormat)

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

    private func removeCurrentNode() {
        if let node = currentAVAudioUnit {
            engine.stop()
            engine.disconnectNodeInput(engine.mainMixerNode)
            engine.disconnectNodeOutput(engine.inputNode)
            engine.detach(node)
            currentAVAudioUnit = nil
        }
    }

    private func acceptsAudioInput(component: AudioUnitComponent) -> Bool {
        let type = component.componentDescription.componentType
        return type == kAudioUnitType_Effect || type == kAudioUnitType_MusicEffect
    }
}
