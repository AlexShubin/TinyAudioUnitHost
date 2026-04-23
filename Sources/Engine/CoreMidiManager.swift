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

final class CoreMidiManager: CoreMidiManagerType {
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

        status = MIDIInputPortCreateWithProtocol(
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
