//
//  AudioUnitEngine.swift
//  TinyAudioUnitHost
//
//  Created by Alex Shubin on 19.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

@preconcurrency import AVFoundation
@preconcurrency import CoreAudio
@preconcurrency import CoreAudioKit

protocol AudioUnitEngineType: Actor, Observable {
    func stop()
    func start()
    func bindDevice(_ deviceID: AudioDeviceID?)
    func connectInputs(channels: SelectedChannel, hardwareOffset: Int)
    func connectOutputs(channels: SelectedChannel, hardwareOffset: Int)
    func disconnect()
    func connectMidi()
    func teardownMidi()
    func load(audioUnit: AudioUnitComponent) async -> LoadedAudioUnit?
    func unloadAudioUnit()
}

final actor AudioUnitEngine: AudioUnitEngineType {
    private let engine = AVAudioEngine()
    private var currentAVAudioUnit: AVAudioUnit?

    private let coreMidiManager: CoreMidiManagerType

    init(coreMidiManager: CoreMidiManagerType) {
        self.coreMidiManager = coreMidiManager
    }

    func start() {
        try? engine.start()
    }

    func stop() {
        engine.stop()
    }

    func bindDevice(_ deviceID: AudioDeviceID?) {
        guard let deviceID, let audioUnit = engine.outputNode.audioUnit else { return }
        setCurrentDevice(deviceID, on: audioUnit)
    }

    private func setCurrentDevice(_ deviceID: AudioDeviceID, on audioUnit: AudioUnit) {
        var id = deviceID
        let size = UInt32(MemoryLayout<UInt32>.size)
        let status = AudioUnitSetProperty(
            audioUnit,
            kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global,
            0,
            &id,
            size
        )
        assert(status == noErr, "Failed to set current device: \(status)")
    }

    func connectInputs(channels: SelectedChannel, hardwareOffset: Int) {
        guard let avAudioUnit = currentAVAudioUnit, acceptsAudioInput(avAudioUnit) else { return }
        let hardwareFormat = engine.outputNode.outputFormat(forBus: 0)
        let auInputChannels = avAudioUnit.auAudioUnit.inputBusses[0].format.channelCount
        let requestedChannels = min(channelCount(for: channels), auInputChannels)
        let inputFormat = AVAudioFormat(
            standardFormatWithSampleRate: hardwareFormat.sampleRate,
            channels: requestedChannels
        )
        setInputChannelMap(for: channels, hardwareOffset: hardwareOffset)
        engine.connect(engine.inputNode, to: avAudioUnit, format: inputFormat)
    }

    func connectOutputs(channels: SelectedChannel, hardwareOffset: Int) {
        guard let avAudioUnit = currentAVAudioUnit else { return }
        let hardwareFormat = engine.outputNode.outputFormat(forBus: 0)
        let auOutputChannels = avAudioUnit.auAudioUnit.outputBusses[0].format.channelCount
        let requestedChannels = min(channelCount(for: channels), auOutputChannels)
        let outputFormat = AVAudioFormat(
            standardFormatWithSampleRate: hardwareFormat.sampleRate,
            channels: requestedChannels
        )
        engine.connect(avAudioUnit, to: engine.mainMixerNode, format: outputFormat)
        setOutputChannelMap(for: channels, hardwareOffset: hardwareOffset)
    }

    func disconnect() {
        engine.disconnectNodeInput(engine.mainMixerNode)
        engine.disconnectNodeOutput(engine.inputNode)
    }

    func connectMidi() {
        guard let avAudioUnit = currentAVAudioUnit else { return }
        coreMidiManager.setupMIDI(for: avAudioUnit.auAudioUnit)
    }

    func teardownMidi() {
        coreMidiManager.teardownMIDI()
    }

    func load(audioUnit: AudioUnitComponent) async -> LoadedAudioUnit? {
        guard audioUnit.componentDescription.componentType != kAudioUnitType_Output else {
            return nil
        }
        do {
            let avAudioUnit = try await AVAudioUnit.instantiate(
                with: audioUnit.componentDescription,
                options: .loadOutOfProcess
            )

            currentAVAudioUnit = avAudioUnit
            engine.attach(avAudioUnit)

            return LoadedAudioUnit(component: audioUnit) {
                await withCheckedContinuation { continuation in
                    avAudioUnit.auAudioUnit.requestViewController { continuation.resume(returning: $0) }
                }
            }
        } catch {
            return nil
        }
    }

    func unloadAudioUnit() {
        guard let node = currentAVAudioUnit else { return }
        engine.detach(node)
        currentAVAudioUnit = nil
    }

    private func channelCount(for selection: SelectedChannel) -> UInt32 {
        switch selection {
        case .mono: return 1
        case .stereo: return 2
        }
    }

    private func setInputChannelMap(for selection: SelectedChannel, hardwareOffset: Int) {
        guard let inputAudioUnit = engine.inputNode.audioUnit else { return }
        // Input HAL: length = virtual channels, map[virtual] = physical (0-indexed).
        let map: [Int32] = selection.channels.map { Int32(hardwareOffset) + Int32($0.id) - 1 }
        setChannelMap(map, on: inputAudioUnit, element: 1)
    }

    private func setOutputChannelMap(for selection: SelectedChannel, hardwareOffset: Int) {
        guard let outputAudioUnit = engine.outputNode.audioUnit,
              let physicalCount = physicalChannelCount(of: outputAudioUnit)
        else { return }
        // Output HAL: length = physical channels, map[physical] = virtual (0-indexed) or -1.
        var map = [Int32](repeating: -1, count: physicalCount)
        for (virtualIdx, channel) in selection.channels.enumerated() {
            let physicalIdx = hardwareOffset + Int(channel.id) - 1
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
            element, // 1 input bus, 0 output bus
            &mutableMap,
            size
        )
        assert(status == noErr, "Failed to set channel map: \(status)")
    }

    private func acceptsAudioInput(_ avAudioUnit: AVAudioUnit) -> Bool {
        let type = avAudioUnit.audioComponentDescription.componentType
        return type == kAudioUnitType_Effect || type == kAudioUnitType_MusicEffect
    }
}
