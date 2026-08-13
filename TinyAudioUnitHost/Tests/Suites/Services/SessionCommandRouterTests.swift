//
//  SessionCommandRouterTests.swift
//  TinyAudioUnitHostTests
//
//  Created by Alex Shubin on 12.08.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import Foundation
import Testing
@testable import TinyAudioUnitHost

@MainActor
@Suite
struct SessionCommandRouterTests {
    var sut: SessionCommandRouter!

    mutating func createSut() {
        sut = SessionCommandRouter()
    }

    @Test
    mutating func executeSaveAsCommand_invokesSetCommand() {
        createSut()
        var count = 0
        sut.setSaveAsCommand { count += 1 }

        sut.executeSaveAsCommand()

        #expect(count == 1)
    }

    @Test
    mutating func setCommand_replacesPreviousCommand() {
        createSut()
        var firstCount = 0
        var secondCount = 0
        sut.setSaveAsCommand { firstCount += 1 }
        sut.setSaveAsCommand { secondCount += 1 }

        sut.executeSaveAsCommand()

        #expect(firstCount == 0)
        #expect(secondCount == 1)
    }
}
