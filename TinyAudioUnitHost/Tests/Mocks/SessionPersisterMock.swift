//
//  SessionPersisterMock.swift
//  TinyAudioUnitHostTests
//
//  Created by Alex Shubin on 07.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import EngineKit
@testable import TinyAudioUnitHost

actor SessionPersisterMock: SessionPersisterType {
    enum Calls: Equatable, Sendable {
        case setCurrent(LoadedAudioUnit?)
        case persistSession
    }

    private(set) var calls: [Calls] = []

    func setCurrent(_ loaded: LoadedAudioUnit?) {
        calls.append(.setCurrent(loaded))
    }

    func persistSession() {
        calls.append(.persistSession)
    }
}
