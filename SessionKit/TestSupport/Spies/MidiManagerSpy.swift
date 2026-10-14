//
//  MidiManagerSpy.swift
//  SessionKitTestSupport
//
//  Created by Alex Shubin on 30.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioUnitsKit
import SessionKit

public final class MidiManagerSpy: MidiManagerType, @unchecked Sendable {
    public enum Calls: Equatable {
        case setupMIDI(LoadedAudioUnit)
        case teardownMIDI
        case reconnectMIDISources
    }

    public private(set) var calls: [Calls] = []

    public init() {}

    public func setupMIDI(for audioUnit: LoadedAudioUnit) async {
        calls.append(.setupMIDI(audioUnit))
    }

    public func teardownMIDI() async {
        calls.append(.teardownMIDI)
    }

    public func reconnectMIDISources() async {
        calls.append(.reconnectMIDISources)
    }
}
