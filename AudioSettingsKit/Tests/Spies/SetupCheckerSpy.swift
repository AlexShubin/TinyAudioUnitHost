//
//  SetupCheckerSpy.swift
//  AudioSettingsKitTests
//
//  Created by Alex Shubin on 22.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

@testable import AudioSettingsKit

final class SetupCheckerSpy: SetupCheckerType, @unchecked Sendable {
    enum Calls: Equatable {
        case check(AudioSettings)
    }

    private(set) var calls: [Calls] = []

    var checkResult: Set<SetupRequirement> = []
    func check(_ settings: AudioSettings) async -> Set<SetupRequirement> {
        calls.append(.check(settings))
        return checkResult
    }
}
