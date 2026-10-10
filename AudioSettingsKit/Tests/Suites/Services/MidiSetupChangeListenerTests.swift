//
//  MidiSetupChangeListenerTests.swift
//  AudioSettingsKitTests
//
//  Created by Alex Shubin on 08.10.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import Common
import Testing
@testable import AudioSettingsKit

@Suite
struct MidiSetupChangeListenerTests {
    var gatewaySpy: CoreMidiGatewaySpy!
    var sut: MidiSetupChangeListenerType!
    var observation: Cancellation?

    init() {
        gatewaySpy = CoreMidiGatewaySpy()
    }

    mutating func createSut() {
        sut = MidiSetupChangeListener(gateway: gatewaySpy)
    }

    @Test
    mutating func observeChanges_createsClientAndForwardsSetupChanges() async {
        createSut()
        let handled = Handled()

        observation = sut.observeChanges { handled.count += 1 }
        await gatewaySpy.setupChangeHandler?()

        #expect(gatewaySpy.calls == [.createClient("TinyAUHost-AudioSettings")])
        #expect(handled.count == 1)
    }

    @Test
    mutating func observeChanges_disposesClientWhenCancelled() {
        gatewaySpy.createClientResult = 9
        createSut()

        observation = sut.observeChanges {}
        observation = nil

        #expect(gatewaySpy.calls == [.createClient("TinyAUHost-AudioSettings"), .disposeClient(9)])
    }

    @Test
    mutating func observeChanges_withoutClientDisposesNothing() {
        gatewaySpy.createClientResult = nil
        createSut()

        observation = sut.observeChanges {}
        observation = nil

        #expect(gatewaySpy.calls == [.createClient("TinyAUHost-AudioSettings")])
    }
}

private final class Handled: @unchecked Sendable {
    var count = 0
}
