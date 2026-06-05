//
//  MidiManager.swift
//  EngineKit
//
//  Created by Alex Shubin on 19.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import CoreMIDI
// AUAudioUnit's RT-safe surface (scheduleMIDIEventListBlock) is thread-safe
// per Apple, but the type isn't Sendable. We only touch it inside a CoreMIDI
// block; the reference doesn't escape this actor beyond that block.
@preconcurrency import AVFoundation

public protocol MidiManagerType: Sendable {
    @discardableResult
    func startListening() -> Task<Void, Error>
    func setupMIDI(for audioUnit: AUAudioUnit) async
    func teardownMIDI() async
}

actor MidiManager: MidiManagerType {
    private var midiClient: MIDIClientRef = 0
    private var midiInputPort: MIDIPortRef = 0

    @discardableResult
    nonisolated func startListening() -> Task<Void, Error> {
        Task { await self.startListeningToSetupChangedIfNeeded() }
    }

    func setupMIDI(for audioUnit: AUAudioUnit) {
        startListeningToSetupChangedIfNeeded()
        guard midiClient != 0 else { return }

        let status = MIDIInputPortCreateWithProtocol(
            midiClient,
            "Input" as CFString,
            ._1_0,
            &midiInputPort
        ) { eventList, _ in
            _ = audioUnit.scheduleMIDIEventListBlock?(AUEventSampleTimeImmediate, 0, eventList)
        }
        guard status == noErr else { return }

        connectAllMIDISources()
    }

    func teardownMIDI() {
        MIDIPortDispose(midiInputPort)
        midiInputPort = 0
    }

    private func startListeningToSetupChangedIfNeeded() {
        guard midiClient == 0 else { return }
        let status = MIDIClientCreateWithBlock("TinyAUHost" as CFString, &midiClient) { [weak self] notification in
            if notification.pointee.messageID == .msgSetupChanged {
                Task { await self?.connectAllMIDISources() }
            }
        }
        if status != noErr { midiClient = 0 }
    }

    private func connectAllMIDISources() {
        guard midiInputPort != 0 else { return }
        let sourceCount = MIDIGetNumberOfSources()
        for i in 0..<sourceCount {
            let source = MIDIGetSource(i)
            MIDIPortConnectSource(midiInputPort, source, nil)
        }
    }
}
