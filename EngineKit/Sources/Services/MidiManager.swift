//
//  MidiManager.swift
//  EngineKit
//
//  Created by Alex Shubin on 19.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioSettingsKit
import AudioUnitsKit

public protocol MidiManagerType: Sendable {
    func setupMIDI(for audioUnit: AUAudioUnitWrapper) async
    func teardownMIDI() async
    func reconnectMIDISources() async
}

actor MidiManager: MidiManagerType {
    private let coreMidiGateway: CoreMidiGatewayType
    private let audioSettings: AudioSettingsProviderType
    private var midiClient: UInt32 = 0
    private var midiInputPort: UInt32 = 0
    private var connectedSources: Set<UInt32> = []

    init(
        coreMidiGateway: CoreMidiGatewayType,
        audioSettings: AudioSettingsProviderType
    ) {
        self.coreMidiGateway = coreMidiGateway
        self.audioSettings = audioSettings
    }

    func setupMIDI(for audioUnit: AUAudioUnitWrapper) {
        guard startClient() else { return }

        guard let port = coreMidiGateway.createInputPort(
            client: midiClient,
            name: "Input",
            audioUnit: audioUnit
        ) else { return }
        midiInputPort = port

        reconnectMIDISources()
    }

    func teardownMIDI() {
        coreMidiGateway.disposePort(midiInputPort)
        midiInputPort = 0
        connectedSources = []
    }

    func reconnectMIDISources() {
        guard midiInputPort != 0 else { return }
        let selected = Set(audioSettings.current.selectedMidiDevices.map(\.ref))
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
        guard let (client, _) = coreMidiGateway.createClient(name: "TinyAUHost") else { return false }
        midiClient = client
        return true
    }
}
