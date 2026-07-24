//
//  MidiManagerMock.swift
//  EngineKitTestSupport
//
//  Created by Alex Shubin on 30.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioUnitsKit
import EngineKit

public final class MidiManagerMock: MidiManagerType, @unchecked Sendable {
    public enum Calls: Equatable {
        case setupMIDI(AUAudioUnitWrapper)
        case teardownMIDI
        case reconnectMIDISources
    }

    public private(set) var calls: [Calls] = []

    public init() {}

    public func setupMIDI(for audioUnit: AUAudioUnitWrapper) async {
        calls.append(.setupMIDI(audioUnit))
    }

    public func teardownMIDI() async {
        calls.append(.teardownMIDI)
    }

    public func reconnectMIDISources() async {
        calls.append(.reconnectMIDISources)
    }
}
