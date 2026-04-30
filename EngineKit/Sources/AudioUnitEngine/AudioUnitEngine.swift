//
//  AudioUnitEngine.swift
//  EngineKit
//
//  Created by Alex Shubin on 19.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

@preconcurrency import AVFoundation
@preconcurrency import CoreAudio
@preconcurrency import CoreAudioKit
import Common

protocol AudioUnitEngineType: Actor {
    func stop()
    func start()
    func bindDevice(_ target: TargetAudioDevice?)
    func setBufferSize(_ frames: UInt32, deviceID: AudioDeviceID)
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
    private let inputMixer = AVAudioMixerNode()
    private var currentAVAudioUnit: AVAudioUnit?

    private let coreMidiManager: CoreMidiManagerType

    init(coreMidiManager: CoreMidiManagerType) {
        self.coreMidiManager = coreMidiManager
        engine.attach(inputMixer)
    }

    func start() {
        try? engine.start()
    }

    func stop() {
        engine.stop()
    }

    func bindDevice(_ target: TargetAudioDevice?) {
        guard let target, let audioUnit = engine.outputNode.audioUnit else { return }
        audioUnit.setEnableIOFlag(target.inputSource != nil, scope: kAudioUnitScope_Input, element: 1)
        audioUnit.setEnableIOFlag(target.outputSource != nil, scope: kAudioUnitScope_Output, element: 0)
        audioUnit.setCurrentDevice(target.device.id)
    }

    func setBufferSize(_ frames: UInt32, deviceID: AudioDeviceID) {
        var size = frames
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyBufferFrameSize,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = AudioObjectSetPropertyData(
            deviceID,
            &address,
            0,
            nil,
            UInt32(MemoryLayout<UInt32>.size),
            &size
        )
        assert(status == noErr, "Failed to set buffer size: \(status)")
    }

    func connectInputs(channels: SelectedChannel, hardwareOffset: Int) {
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
        engine.inputNode.audioUnit?.setInputChannelMap(for: channels, hardwareOffset: hardwareOffset)
        engine.connect(engine.inputNode, to: inputMixer, format: userFormat)
        engine.connect(inputMixer, to: avAudioUnit, format: auInputFormat)
    }

    func connectOutputs(channels: SelectedChannel, hardwareOffset: Int) {
        guard let avAudioUnit = currentAVAudioUnit else { return }
        let hardwareFormat = engine.outputNode.outputFormat(forBus: 0)
        let outputFormat = AVAudioFormat(
            standardFormatWithSampleRate: hardwareFormat.sampleRate,
            channels: avAudioUnit.auAudioUnit.outputBusses[0].format.channelCount
        )
        engine.connect(avAudioUnit, to: engine.mainMixerNode, format: outputFormat)
        engine.outputNode.audioUnit?.setOutputChannelMap(for: channels, hardwareOffset: hardwareOffset)
    }

    func disconnect() {
        engine.disconnectNodeInput(engine.mainMixerNode)
        engine.disconnectNodeOutput(inputMixer)
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

fileprivate extension AudioUnit {
    func setEnableIOFlag(_ enabled: Bool, scope: AudioUnitScope, element: AudioUnitElement) {
        var flag: UInt32 = enabled ? 1 : 0
        let status = AudioUnitSetProperty(
            self,
            kAudioOutputUnitProperty_EnableIO,
            scope,
            element,
            &flag,
            UInt32(MemoryLayout<UInt32>.size)
        )
        assert(status == noErr, "Failed to set EnableIO: \(status)")
    }

    func setCurrentDevice(_ deviceID: AudioDeviceID) {
        var id = deviceID
        let size = UInt32(MemoryLayout<UInt32>.size)
        let status = AudioUnitSetProperty(
            self,
            kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global,
            0,
            &id,
            size
        )
        assert(status == noErr, "Failed to set current device: \(status)")
    }

    func setInputChannelMap(for selection: SelectedChannel, hardwareOffset: Int) {
        // Input HAL: length = virtual channels, map[virtual] = physical (0-indexed).
        let map: [Int32] = selection.channels.map { Int32(hardwareOffset) + Int32($0.id) - 1 }
        setChannelMap(map, element: 1)
    }

    func setOutputChannelMap(for selection: SelectedChannel, hardwareOffset: Int) {
        guard let physicalCount = physicalChannelCount else { return }
        // Output HAL: length = physical channels, map[physical] = virtual (0-indexed) or -1.
        var map = [Int32](repeating: -1, count: physicalCount)
        for (virtualIdx, channel) in selection.channels.enumerated() {
            let physicalIdx = hardwareOffset + Int(channel.id) - 1
            guard physicalIdx >= 0, physicalIdx < physicalCount else { continue }
            map[physicalIdx] = Int32(virtualIdx)
        }
        setChannelMap(map, element: 0)
    }

    var physicalChannelCount: Int? {
        var streamFormat = AudioStreamBasicDescription()
        var size = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        let status = AudioUnitGetProperty(
            self,
            kAudioUnitProperty_StreamFormat,
            kAudioUnitScope_Output,
            0,
            &streamFormat,
            &size
        )
        guard status == noErr else { return nil }
        return Int(streamFormat.mChannelsPerFrame)
    }

    func setChannelMap(_ map: [Int32], element: AudioUnitElement) {
        var mutableMap = map
        let size = UInt32(MemoryLayout<Int32>.size * mutableMap.count)
        let status = AudioUnitSetProperty(
            self,
            kAudioOutputUnitProperty_ChannelMap,
            kAudioUnitScope_Output,
            element, // 1 input bus, 0 output bus
            &mutableMap,
            size
        )
        assert(status == noErr, "Failed to set channel map: \(status)")
    }
}
