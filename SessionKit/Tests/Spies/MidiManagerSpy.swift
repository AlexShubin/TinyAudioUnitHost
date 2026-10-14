//
//  MidiManagerSpy.swift
//  SessionKitTests
//
//  Created by Alex Shubin on 30.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioUnitsKit
@testable import SessionKit

final class MidiManagerSpy: MidiManagerType, @unchecked Sendable {
    enum Calls: Equatable {
        case setupMIDI(LoadedAudioUnit)
        case teardownMIDI
        case reconnectMIDISources
    }

    private(set) var calls: [Calls] = []

    func setupMIDI(for audioUnit: LoadedAudioUnit) async {
        calls.append(.setupMIDI(audioUnit))
    }

    func teardownMIDI() async {
        calls.append(.teardownMIDI)
    }

    func reconnectMIDISources() async {
        calls.append(.reconnectMIDISources)
    }
}
