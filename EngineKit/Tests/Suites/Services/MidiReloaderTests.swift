//
//  MidiReloaderTests.swift
//  EngineKitTests
//
//  Created by Alex Shubin on 24.07.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import EngineKitTestSupport
import Testing
@testable import EngineKit

@MainActor
@Suite
struct MidiReloaderTests {
    var coreMidiGatewayMock: CoreMidiGatewayMock!
    var midiManagerMock: MidiManagerMock!
    var sut: MidiReloaderType!

    init() {
        coreMidiGatewayMock = CoreMidiGatewayMock()
        midiManagerMock = MidiManagerMock()
    }

    mutating func createSut() {
        sut = MidiReloader(
            coreMidiGateway: coreMidiGatewayMock,
            midiManager: midiManagerMock
        )
    }

    @Test
    mutating func start_createsClient() {
        createSut()

        sut.start()

        #expect(coreMidiGatewayMock.calls == [.createClient("TinyAUHost-MidiReloader")])
    }

    @Test
    mutating func start_calledTwice_createsClientOnce() {
        createSut()

        sut.start()
        sut.start()

        #expect(coreMidiGatewayMock.calls == [.createClient("TinyAUHost-MidiReloader")])
    }

    @Test
    mutating func start_setupChanged_reconnectsMIDISources() async {
        createSut()

        let task = sut.start()
        coreMidiGatewayMock.setupChangesStream.continuation.yield()
        coreMidiGatewayMock.setupChangesStream.continuation.finish()
        try? await task.value

        #expect(midiManagerMock.calls == [.reconnectMIDISources])
    }

    @Test
    mutating func start_noSetupChange_doesNotReconnect() async {
        createSut()

        let task = sut.start()
        coreMidiGatewayMock.setupChangesStream.continuation.finish()
        try? await task.value

        #expect(midiManagerMock.calls.isEmpty)
    }

    @Test
    mutating func start_clientCreationFails_doesNotReconnect() async {
        coreMidiGatewayMock.createClientResult = nil
        createSut()

        let task = sut.start()
        try? await task.value

        #expect(midiManagerMock.calls.isEmpty)
    }
}
