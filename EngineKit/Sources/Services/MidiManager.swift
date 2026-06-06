//
//  MidiManager.swift
//  EngineKit
//
//  Created by Alex Shubin on 19.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioUnitsKit

public protocol MidiManagerType: Sendable {
    @discardableResult
    func startListening() -> Task<Void, Error>
    func setupMIDI(for audioUnit: AUAudioUnitWrapper) async
    func teardownMIDI() async
}

actor MidiManager: MidiManagerType {
    private let coreMidiGateway: CoreMidiGatewayType
    private var midiClient: UInt32 = 0
    private var midiInputPort: UInt32 = 0
    private var setupChanges: AsyncStream<Void>?

    init(coreMidiGateway: CoreMidiGatewayType) {
        self.coreMidiGateway = coreMidiGateway
    }

    @discardableResult
    nonisolated func startListening() -> Task<Void, Error> {
        Task {
            guard let setupChanges = await self.startClient() else { return }
            for await _ in setupChanges {
                await self.connectAllMIDISources()
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

        connectAllMIDISources()
    }

    func teardownMIDI() {
        coreMidiGateway.disposePort(midiInputPort)
        midiInputPort = 0
    }

    @discardableResult
    private func startClient() -> AsyncStream<Void>? {
        if let setupChanges { return setupChanges }
        guard let (client, stream) = coreMidiGateway.createClient(name: "TinyAUHost") else { return nil }
        midiClient = client
        setupChanges = stream
        return stream
    }

    private func connectAllMIDISources() {
        guard midiInputPort != 0 else { return }
        for index in 0..<coreMidiGateway.sourceCount {
            coreMidiGateway.connect(source: coreMidiGateway.source(at: index), to: midiInputPort)
        }
    }
}
