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
    mutating func executeSavedCommand_invokesSetCommand() {
        createSut()
        var count = 0
        sut.setSavedCommand { count += 1 }

        sut.executeSavedCommand()

        #expect(count == 1)
    }

    @Test
    mutating func executeRestoredCommand_invokesSetCommand() {
        createSut()
        var count = 0
        sut.setRestoredCommand { count += 1 }

        sut.executeRestoredCommand()

        #expect(count == 1)
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
    mutating func execute_invokesOnlyItsOwnCommand() {
        createSut()
        var savedCount = 0
        var restoredCount = 0
        var saveAsCount = 0
        sut.setSavedCommand { savedCount += 1 }
        sut.setRestoredCommand { restoredCount += 1 }
        sut.setSaveAsCommand { saveAsCount += 1 }

        sut.executeSavedCommand()

        #expect(savedCount == 1)
        #expect(restoredCount == 0)
        #expect(saveAsCount == 0)
    }

    @Test
    mutating func setCommand_replacesPreviousCommand() {
        createSut()
        var firstCount = 0
        var secondCount = 0
        sut.setSavedCommand { firstCount += 1 }
        sut.setSavedCommand { secondCount += 1 }

        sut.executeSavedCommand()

        #expect(firstCount == 0)
        #expect(secondCount == 1)
    }
}
