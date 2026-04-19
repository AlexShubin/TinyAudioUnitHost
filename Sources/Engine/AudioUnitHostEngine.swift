//
//  AudioUnitHostEngine.swift
//  TinyAudioUnitHost
//
//  Created by Alex Shubin on 19.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AVFoundation
import CoreMIDI

struct AudioUnitComponent: Sendable, Identifiable, Hashable {
    let id: String
    let name: String
    let manufacturer: String
    let componentDescription: AudioComponentDescription

    static func == (lhs: AudioUnitComponent, rhs: AudioUnitComponent) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

protocol AudioUnitHostEngineType: Observable, Sendable {
    var availableInstruments: [AudioUnitComponent] { get }

    func loadInstruments() async
    func select(_ component: AudioUnitComponent) async -> AUAudioUnit?
}

final class AudioUnitHostEngine: AudioUnitHostEngineType, @unchecked Sendable {
    private(set) var availableInstruments: [AudioUnitComponent] = []

    private let engine = AVAudioEngine()
    private var currentNode: AVAudioUnit?
    private var midiClient = MIDIClientRef()
    private var midiInputPort = MIDIPortRef()
    private var midiSetUp = false

    func loadInstruments() async {
        let components = await withCheckedContinuation { continuation in
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
        availableInstruments = components
    }

    func select(_ component: AudioUnitComponent) async -> AUAudioUnit? {
        teardownMIDI()
        removeCurrentNode()

        do {
            let avAudioUnit = try await AVAudioUnit.instantiate(
                with: component.componentDescription,
                options: .loadOutOfProcess
            )

            let currentAudioUnit = avAudioUnit.auAudioUnit
            currentNode = avAudioUnit

            engine.attach(avAudioUnit)

            let hardwareFormat = engine.outputNode.outputFormat(forBus: 0)
            let stereoFormat = AVAudioFormat(
                standardFormatWithSampleRate: hardwareFormat.sampleRate,
                channels: 2
            )
            engine.connect(avAudioUnit, to: engine.mainMixerNode, format: stereoFormat)
            engine.connect(engine.mainMixerNode, to: engine.outputNode, format: hardwareFormat)

            try engine.start()

            setupMIDI()

            return currentAudioUnit
        } catch {
            return nil
        }
    }

    private func removeCurrentNode() {
        if let node = currentNode {
            engine.stop()
            engine.disconnectNodeInput(engine.mainMixerNode)
            engine.detach(node)
            currentNode = nil
        }
    }

    private func setupMIDI() {
        guard !midiSetUp else { return }
        midiSetUp = true

        var status = MIDIClientCreateWithBlock("TinyAUHost" as CFString, &midiClient) { [weak self] notification in
            if notification.pointee.messageID == .msgSetupChanged {
                self?.connectAllMIDISources()
            }
        }
        guard status == noErr else { return }

        status = MIDIInputPortCreateWithBlock(midiClient, "Input" as CFString, &midiInputPort) { [weak self] packetList, srcConnRefCon in
            guard let self = self else {
                return
            }
            guard let noteBlock = self.currentNode?.auAudioUnit.scheduleMIDIEventBlock else {
                return
            }

            let packets = packetList.pointee
            var packet = packets.packet
            for _ in 0..<packets.numPackets {
                let length = Int(packet.length)
                if length >= 1 {
                    let bytes = UnsafeMutablePointer<UInt8>.allocate(capacity: length)
                    withUnsafePointer(to: &packet.data) { tuplePtr in
                        tuplePtr.withMemoryRebound(to: UInt8.self, capacity: length) { src in
                            bytes.initialize(from: src, count: length)
                        }
                    }
                    noteBlock(AUEventSampleTimeImmediate, 0, length, bytes)
                    bytes.deallocate()
                }
                packet = MIDIPacketNext(&packet).pointee
            }
        }
        guard status == noErr else { return }

        connectAllMIDISources()
    }

    private func connectAllMIDISources() {
        let sourceCount = MIDIGetNumberOfSources()
        for i in 0..<sourceCount {
            let source = MIDIGetSource(i)
            MIDIPortConnectSource(midiInputPort, source, nil)
        }
    }

    private func teardownMIDI() {
        guard midiSetUp else { return }
        MIDIPortDispose(midiInputPort)
        MIDIClientDispose(midiClient)
        midiSetUp = false
    }
}
