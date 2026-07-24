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
    @discardableResult
    func startListening() -> Task<Void, Error>
    func setupMIDI(for audioUnit: AUAudioUnitWrapper) async
    func teardownMIDI() async
    func reconnectMIDISources() async
}

actor MidiManager: MidiManagerType {
    private let coreMidiGateway: CoreMidiGatewayType
    private let audioSettings: AudioSettingsProviderType
    private var midiClient: UInt32 = 0
    private var midiInputPort: UInt32 = 0
    private var setupChanges: AsyncStream<Void>?
    private var connectedSources: Set<UInt32> = []

    init(
        coreMidiGateway: CoreMidiGatewayType,
        audioSettings: AudioSettingsProviderType
    ) {
        self.coreMidiGateway = coreMidiGateway
        self.audioSettings = audioSettings
    }

    @discardableResult
    nonisolated func startListening() -> Task<Void, Error> {
        Task {
            guard let setupChanges = await self.startClient() else { return }
            for await _ in setupChanges {
                await self.reconnectMIDISources()
            }
        }
    }

    func setupMIDI(for audioUnit: AUAudioUnitWrapper) {
        guard startClient() != nil else { return }

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

    @discardableResult
    private func startClient() -> AsyncStream<Void>? {
        if let setupChanges { return setupChanges }
        guard let (client, stream) = coreMidiGateway.createClient(name: "TinyAUHost") else { return nil }
        midiClient = client
        setupChanges = stream
        return stream
    }
}
