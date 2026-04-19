//
//  AudioUnitHostEngine.swift
//  TinyAudioUnitHost
//
//  Created by Alex Shubin on 19.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AVFoundation
import CoreMIDI

// Sendable reference-type container for the AU MIDI block. The block is
// written only from the MainActor (inside `select(_:)`) and read from the
// CoreMIDI thread. A Mutex would add unacceptable priority inversion for
// real-time MIDI; pointer-sized writes are effectively atomic on supported
// hardware and the AU contract already requires the block to tolerate being
// called from arbitrary threads.
private final class MIDIBlockBox: @unchecked Sendable {
    nonisolated(unsafe) var block: AUScheduleMIDIEventBlock?
}

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

@MainActor
protocol AudioUnitHostEngineType: Observable, Sendable {
    var availableInstruments: [AudioUnitComponent] { get }

    func loadInstruments() async
    func select(_ component: AudioUnitComponent) async -> AUAudioUnit?
}

@MainActor
final class AudioUnitHostEngine: AudioUnitHostEngineType {
    private(set) var availableInstruments: [AudioUnitComponent] = []

    private let engine = AVAudioEngine()
    private var currentNode: AVAudioUnit?
    private var midiClient = MIDIClientRef()
    private var midiInputPort = MIDIPortRef()
    private var midiSetUp = false

    // Holds the AU MIDI block in a Sendable box so CoreMIDI callbacks never
    // need to touch `self`. Capturing `[weak self]` of a @MainActor class in a
    // Sendable callback triggers Swift 6's runtime isolation check
    // (swift_task_isCurrentExecutorWithFlagsImpl) on the CoreMIDI thread, which
    // crashes via dispatch_assert_queue_fail.
    private let midiBlockBox = MIDIBlockBox()

    nonisolated init() {}

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
            // scheduleMIDIEventBlock is only valid after render resources are
            // allocated, which happens during engine.start().
            midiBlockBox.block = avAudioUnit.auAudioUnit.scheduleMIDIEventBlock
            setupMIDI()

            return currentAudioUnit
        } catch {
            return nil
        }
    }

    private func removeCurrentNode() {
        midiBlockBox.block = nil
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

        MIDIClientCreateWithBlock("TinyAUHost" as CFString, &midiClient) { [weak self] notification in
            if notification.pointee.messageID == .msgSetupChanged {
                Task { @MainActor in
                    self?.connectAllMIDISources()
                }
            }
        }

        // Capture only the Sendable box — never `self`. Touching a
        // @MainActor-isolated class (even via [weak self]) from the CoreMIDI
        // thread triggers Swift 6's runtime isolation assertion.
        let box = midiBlockBox
        MIDIInputPortCreateWithBlock(midiClient, "Input" as CFString, &midiInputPort) { packetListPtr, _ in
            // Copy packet bytes off the CoreMIDI thread into plain Swift arrays,
            // then deliver to the AU on the main queue. Out-of-process AUv3
            // extensions frequently assert their scheduleMIDIEventBlock is
            // invoked on a specific (usually main) queue, even though the
            // header claims any thread is safe.
            var events: [[UInt8]] = []
            for packetPtr in packetListPtr.unsafeSequence() {
                let length = Int(packetPtr.pointee.length)
                guard length >= 1 else { continue }

                var packet = packetPtr.pointee
                var buffer = [UInt8](repeating: 0, count: length)
                withUnsafePointer(to: &packet.data) { tuplePtr in
                    tuplePtr.withMemoryRebound(to: UInt8.self, capacity: length) { src in
                        buffer.withUnsafeMutableBufferPointer { dst in
                            dst.baseAddress?.initialize(from: src, count: length)
                        }
                    }
                }

                // Skip MIDI real-time messages (0xF8...0xFF).
                guard buffer[0] < 0xF8 else { continue }
                events.append(buffer)
            }

            guard !events.isEmpty else { return }

            DispatchQueue.main.async {
                for event in events {
                    event.withUnsafeBufferPointer { ptr in
                        guard let base = ptr.baseAddress,
                              let noteBlock = box.block else { return }
                        noteBlock(AUEventSampleTimeImmediate, 0, event.count, base)
                    }
                }
            }
        }

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
