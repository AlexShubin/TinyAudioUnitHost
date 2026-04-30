//
//  CoreMidiManagerMock.swift
//  EngineKitTests
//
//  Created by Alex Shubin on 30.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AVFoundation
@testable import EngineKit

final class CoreMidiManagerMock: CoreMidiManagerType {
    enum Calls: Equatable {
        case setupMIDI(AUAudioUnit)
        case teardownMIDI
    }

    private(set) var calls: [Calls] = []

    init() {}

    func setupMIDI(for audioUnit: AUAudioUnit) {
        calls.append(.setupMIDI(audioUnit))
    }

    func teardownMIDI() {
        calls.append(.teardownMIDI)
    }
}
