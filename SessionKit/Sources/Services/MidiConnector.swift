//
//  MidiConnector.swift
//  SessionKit
//
//  Created by Alex Shubin on 19.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioSettingsKit
import AudioUnitsKit
import CoreMidiGatewayKit

@MainActor
protocol MidiConnectorType: Sendable {
    func connect(_ audioUnit: LoadedAudioUnit, sources: Set<MidiDevice>) async
    func disconnect() async
    func reconnect(sources: Set<MidiDevice>) async
}

@MainActor
final class MidiConnector: MidiConnectorType {
    private let coreMidiGateway: CoreMidiGatewayType
    private var midiClient: UInt32 = 0
    private var midiInputPort: UInt32 = 0
    private var connectedSources: Set<UInt32> = []

    init(coreMidiGateway: CoreMidiGatewayType) {
        self.coreMidiGateway = coreMidiGateway
    }

    func connect(_ audioUnit: LoadedAudioUnit, sources: Set<MidiDevice>) async {
        disconnect()
        guard startClient() else { return }

        guard let port = coreMidiGateway.createInputPort(
            client: midiClient,
            name: "Input",
            audioUnit: audioUnit
        ) else { return }
        midiInputPort = port

        await reconnect(sources: sources)
    }

    func disconnect() {
        guard midiInputPort != 0 else { return }
        coreMidiGateway.disposePort(midiInputPort)
        midiInputPort = 0
        connectedSources = []
    }

    func reconnect(sources: Set<MidiDevice>) async {
        guard midiInputPort != 0 else { return }
        let selected = Set(sources.map(\.ref))
        for source in connectedSources.subtracting(selected) {
            coreMidiGateway.disconnect(source: source, from: midiInputPort)
        }
        for source in selected.subtracting(connectedSources) {
            coreMidiGateway.connect(source: source, to: midiInputPort)
        }
        connectedSources = selected
    }

    private func startClient() -> Bool {
        if midiClient != 0 { return true }
        guard let client = coreMidiGateway.createClient(name: "TinyAUHost") else { return false }
        midiClient = client
        return true
    }
}
