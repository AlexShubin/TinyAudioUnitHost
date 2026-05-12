//
//  SessionManagerMock.swift
//  TinyAudioUnitHostTests
//
//  Created by Alex Shubin on 09.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioUnitsKit
@testable import TinyAudioUnitHost

actor SessionManagerMock: SessionManagerType {
    enum Calls: Equatable, Sendable {
        case activate(ActivationSource)
        case save
    }

    private(set) var calls: [Calls] = []
    var activateResult: LoadedAudioUnit?

    init(activateResult: LoadedAudioUnit? = nil) {
        self.activateResult = activateResult
    }

    func activate(_ source: ActivationSource) -> LoadedAudioUnit? {
        calls.append(.activate(source))
        return activateResult
    }

    func save() {
        calls.append(.save)
    }

    func setActivateResult(_ value: LoadedAudioUnit?) {
        activateResult = value
    }
}
