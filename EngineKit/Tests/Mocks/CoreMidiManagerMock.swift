//
//  CoreMidiManagerMock.swift
//  EngineKitTests
//
//  Created by Alex Shubin on 30.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

@preconcurrency import AVFoundation
@testable import EngineKit

final class CoreMidiManagerMock: CoreMidiManagerType, @unchecked Sendable {
    enum Calls: Equatable {
        case setupMIDI(AUAudioUnit)
        case teardownMIDI
    }

    private(set) var calls: [Calls] = []

    init() {}

    func setupMIDI(for audioUnit: AUAudioUnit) async {
        calls.append(.setupMIDI(audioUnit))
    }

    func teardownMIDI() async {
        calls.append(.teardownMIDI)
    }
}
