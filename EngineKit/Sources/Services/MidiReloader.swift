//
//  MidiReloader.swift
//  EngineKit
//
//  Created by Alex Shubin on 24.07.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

@MainActor
public protocol MidiReloaderType: Sendable {
    @discardableResult
    func start() -> Task<Void, Error>
}

@MainActor
final class MidiReloader: MidiReloaderType {
    private let coreMidiGateway: CoreMidiGatewayType
    private let midiManager: MidiManagerType
    private var isStarted = false

    nonisolated init(
        coreMidiGateway: CoreMidiGatewayType,
        midiManager: MidiManagerType
    ) {
        self.coreMidiGateway = coreMidiGateway
        self.midiManager = midiManager
    }

    // Must be the process's first CoreMIDI call, made on the main run loop,
    // otherwise the process would never receive another MIDI notification.
    @discardableResult
    func start() -> Task<Void, Error> {
        guard !isStarted,
              let (_, setupChanges) = coreMidiGateway.createClient(name: "TinyAUHost-MidiReloader")
        else { return Task {} }
        isStarted = true
        return Task {
            for await _ in setupChanges {
                await midiManager.reconnectMIDISources()
            }
        }
    }
}
