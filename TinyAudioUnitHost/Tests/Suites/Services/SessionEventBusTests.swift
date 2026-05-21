//
//  SessionEventBusTests.swift
//  TinyAudioUnitHostTests
//
//  Created by Alex Shubin on 21.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import Foundation
import Testing
@testable import TinyAudioUnitHost

@MainActor
@Suite
struct SessionEventBusTests {
    var sut: SessionEventBusType!

    mutating func createSut() {
        sut = SessionEventBus()
    }

    @Test
    mutating func post_deliversToSubscriber() async {
        createSut()
        var iterator = sut.makeEventStream().makeAsyncIterator()

        sut.post(.saved)

        #expect(await iterator.next() == .saved)
    }

    @Test
    mutating func post_fansOutToMultipleSubscribers() async {
        createSut()
        var iteratorA = sut.makeEventStream().makeAsyncIterator()
        var iteratorB = sut.makeEventStream().makeAsyncIterator()

        sut.post(.saveAsRequested)

        #expect(await iteratorA.next() == .saveAsRequested)
        #expect(await iteratorB.next() == .saveAsRequested)
    }

    @Test
    mutating func post_deliversEventsInOrder() async {
        createSut()
        var iterator = sut.makeEventStream().makeAsyncIterator()

        sut.post(.saved)
        sut.post(.restored)
        sut.post(.saveAsRequested)

        #expect(await iterator.next() == .saved)
        #expect(await iterator.next() == .restored)
        #expect(await iterator.next() == .saveAsRequested)
    }

    @Test
    mutating func post_beforeSubscribe_isNotReplayed() async {
        createSut()
        sut.post(.saved)

        var iterator = sut.makeEventStream().makeAsyncIterator()
        sut.post(.restored)

        #expect(await iterator.next() == .restored)
    }
}
