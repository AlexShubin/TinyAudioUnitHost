//
//  MidiConnectorSpy.swift
//  SessionKitTests
//
//  Created by Alex Shubin on 30.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioUnitsKit
@testable import SessionKit

final class MidiConnectorSpy: MidiConnectorType, @unchecked Sendable {
    enum Calls: Equatable {
        case connect(LoadedAudioUnit, SessionHardwareSettings.Midi)
        case disconnect
        case reconnect(SessionHardwareSettings.Midi)
    }

    private(set) var calls: [Calls] = []

    func connect(_ audioUnit: LoadedAudioUnit, settings: SessionHardwareSettings.Midi) async {
        calls.append(.connect(audioUnit, settings))
    }

    func disconnect() async {
        calls.append(.disconnect)
    }

    func reconnect(settings: SessionHardwareSettings.Midi) async {
        calls.append(.reconnect(settings))
    }
}
