//
//  BindableCommandTests.swift
//  TinyAudioUnitHostTests
//
//  Created by Alex Shubin on 13.08.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import Foundation
import Testing
@testable import TinyAudioUnitHost

@MainActor
@Suite
struct BindableCommandTests {
    var sut: BindableCommand!

    mutating func createSut() {
        sut = BindableCommand()
    }

    @Test
    mutating func execute_invokesBoundAction() {
        createSut()
        var count = 0
        sut.bind { count += 1 }

        sut.execute()

        #expect(count == 1)
    }

    @Test
    mutating func bind_replacesPreviousAction() {
        createSut()
        var firstCount = 0
        var secondCount = 0
        sut.bind { firstCount += 1 }
        sut.bind { secondCount += 1 }

        sut.execute()

        #expect(firstCount == 0)
        #expect(secondCount == 1)
    }
}
