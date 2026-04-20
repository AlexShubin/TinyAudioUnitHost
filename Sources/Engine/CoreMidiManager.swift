//
//  CoreMidiManager.swift
//  TinyAudioUnitHost
//
//  Created by Alex Shubin on 19.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import CoreMIDI
import AVFoundation

protocol CoreMidiManagerType {
    func setupMIDI(for audioUnit: AUAudioUnit)
    func teardownMIDI()
}

class CoreMidiManager: CoreMidiManagerType {
    private var midiClient = MIDIClientRef()
    private var midiInputPort = MIDIPortRef()
    private var midiSetUp = false

    func setupMIDI(for audioUnit: AUAudioUnit) {
        guard !midiSetUp else { return }
        midiSetUp = true

        var status = MIDIClientCreateWithBlock("TinyAUHost" as CFString, &midiClient) { [weak self] notification in
            if notification.pointee.messageID == .msgSetupChanged {
                self?.connectAllMIDISources()
            }
        }
        guard status == noErr else { return }

        status = MIDIInputPortCreateWithBlock(midiClient, "Input" as CFString, &midiInputPort) { packetList, srcConnRefCon in
            guard let noteBlock = audioUnit.scheduleMIDIEventBlock else {
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

    func teardownMIDI() {
        guard midiSetUp else { return }
        MIDIPortDispose(midiInputPort)
        MIDIClientDispose(midiClient)
        midiSetUp = false
    }
}
