//
//  QuitCoordinatorTests.swift
//  TinyAudioUnitHostTests
//
//  Created by Alex Shubin on 08.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import Testing
@testable import TinyAudioUnitHost

@Suite
struct QuitCoordinatorTests {
    var sut: QuitCoordinatorType!

    mutating func createSut() {
        sut = QuitCoordinator()
    }

    @Test(arguments: [true, false])
    mutating func requestQuit_resumesWithResolvedValue(proceed: Bool) async {
        createSut()
        var iterator = sut.requests.makeAsyncIterator()

        async let result = sut.requestQuit()
        _ = await iterator.next()
        await sut.resolve(proceed: proceed)

        #expect(await result == proceed)
    }

    @Test
    mutating func resolve_withoutPendingRequest_isNoop() async {
        createSut()

        await sut.resolve(proceed: true)

        var iterator = sut.requests.makeAsyncIterator()
        async let result = sut.requestQuit()
        _ = await iterator.next()
        await sut.resolve(proceed: false)
        #expect(await result == false)
    }

    @Test
    mutating func requestQuit_sequentialRequests_eachResolvedIndependently() async {
        createSut()
        var iterator = sut.requests.makeAsyncIterator()

        async let first = sut.requestQuit()
        _ = await iterator.next()
        await sut.resolve(proceed: true)
        #expect(await first == true)

        async let second = sut.requestQuit()
        _ = await iterator.next()
        await sut.resolve(proceed: false)
        #expect(await second == false)
    }
}
