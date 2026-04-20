//
//  AudioUnitHostEngine.swift
//  TinyAudioUnitHost
//
//  Created by Alex Shubin on 19.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

@preconcurrency import AVFoundation

protocol AudioUnitHostEngineType: Observable, Sendable {
    func load(componentId: String) async -> AUAudioUnit?
}

final actor AudioUnitHostEngine: AudioUnitHostEngineType {
    private let engine = AVAudioEngine()
    private var currentAVAudioUnit: AVAudioUnit?

    private let coreMidiManager: CoreMidiManagerType
    private let audioUnitComponentsLibrary: AudioUnitComponentsLibraryType

    init(
        coreMidiManager: CoreMidiManagerType,
         audioUnitComponentsLibrary: AudioUnitComponentsLibraryType
    ) {
        self.coreMidiManager = coreMidiManager
        self.audioUnitComponentsLibrary = audioUnitComponentsLibrary
    }

    func load(componentId: String) async -> AUAudioUnit? {
        coreMidiManager.teardownMIDI()
        removeCurrentNode()

        guard let componentDescription = audioUnitComponentsLibrary.components.first(where: { $0.id == componentId })?.componentDescription else {
            return nil
        }

        do {
            let avAudioUnit = try await AVAudioUnit.instantiate(
                with: componentDescription,
                options: .loadOutOfProcess
            )

            let currentAudioUnit = avAudioUnit.auAudioUnit
            currentAVAudioUnit = avAudioUnit

            engine.attach(avAudioUnit)

            let hardwareFormat = engine.outputNode.outputFormat(forBus: 0)
            let stereoFormat = AVAudioFormat(
                standardFormatWithSampleRate: hardwareFormat.sampleRate,
                channels: 2
            )
            engine.connect(avAudioUnit, to: engine.mainMixerNode, format: stereoFormat)
            engine.connect(engine.mainMixerNode, to: engine.outputNode, format: hardwareFormat)

            try engine.start()

            coreMidiManager.setupMIDI(for: currentAudioUnit)

            return currentAudioUnit
        } catch {
            return nil
        }
    }

    private func removeCurrentNode() {
        if let node = currentAVAudioUnit {
            engine.stop()
            engine.disconnectNodeInput(engine.mainMixerNode)
            engine.detach(node)
            currentAVAudioUnit = nil
        }
    }
}
