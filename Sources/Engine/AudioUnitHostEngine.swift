//
//  AudioUnitHostEngine.swift
//  TinyAudioUnitHost
//
//  Created by Alex Shubin on 19.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AVFoundation

protocol AudioUnitHostEngineType: Observable, Sendable {
    func load(componentId: String) async -> AUAudioUnit?
}

final class AudioUnitHostEngine: AudioUnitHostEngineType, @unchecked Sendable {
    private let engine = AVAudioEngine()
    private var currentAVAudioUnit: AVAudioUnit?

    private let coreMidiManager: CoreMidiManagerType
    private let audioUnitComponentsLibrary: AudioUnitComponentsLibraryType

    init(coreMidiManager: CoreMidiManagerType,
         audioUnitComponentsLibrary: AudioUnitComponentsLibraryType) {
        self.coreMidiManager = coreMidiManager
        self.audioUnitComponentsLibrary = audioUnitComponentsLibrary
    }

    func load(componentId: String) async -> AUAudioUnit? {
        coreMidiManager.teardownMIDI()
        removeCurrentNode()

        guard let componentDescription = await audioUnitComponentsLibrary.componentDescription(for: componentId) else {
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

struct AudioUnitComponent: Sendable {
    let id: String
    let name: String
    let manufacturer: String
    let componentDescription: AudioComponentDescription
}

protocol AudioUnitComponentsLibraryType: Sendable {
    var components: [AudioUnitComponent] { get async }
    func componentDescription(for componentId: String) async -> AudioComponentDescription?
}

final class AudioUnitComponentsLibrary: AudioUnitComponentsLibraryType, @unchecked Sendable {
    var components: [AudioUnitComponent] {
        get async {
            await withCheckedContinuation { continuation in
                DispatchQueue.global(qos: .userInitiated).async {
                    var desc = AudioComponentDescription()
                    desc.componentType = kAudioUnitType_MusicDevice
                    desc.componentSubType = 0
                    desc.componentManufacturer = 0
                    desc.componentFlags = 0
                    desc.componentFlagsMask = 0

                    let found = AVAudioUnitComponentManager.shared().components(matching: desc)
                    let mapped = found.map { component in
                        AudioUnitComponent(
                            id: "\(component.manufacturerName).\(component.name)",
                            name: component.name,
                            manufacturer: component.manufacturerName,
                            componentDescription: component.audioComponentDescription
                        )
                    }
                    continuation.resume(returning: mapped)
                }
            }
        }
    }

    func componentDescription(for componentId: String) async -> AudioComponentDescription? {
        await components.first(where: { $0.id == componentId })?.componentDescription
    }
}
