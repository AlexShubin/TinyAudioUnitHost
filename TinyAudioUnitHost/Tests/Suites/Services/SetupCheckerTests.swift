//
//  SetupCheckerTests.swift
//  TinyAudioUnitHostTests
//
//  Created by Alex Shubin on 09.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioSettingsKit
import AudioSettingsKitTestSupport
import Foundation
import Testing
@testable import TinyAudioUnitHost

@Suite
struct SetupCheckerTests {
    var targetSettingsMock: TargetSettingsProviderMock!
    var sut: SetupCheckerType!
    var isMicAuthorized = true

    init() {
        targetSettingsMock = TargetSettingsProviderMock()
    }

    mutating func createSut() {
        let mic = isMicAuthorized
        sut = SetupChecker(
            targetSettingsProvider: targetSettingsMock,
            isMicrophoneAuthorized: { mic },
            ensureMicrophoneDecision: {}
        )
    }

    @Test
    mutating func refresh_micAndTargetOK_yieldsEmpty() async {
        targetSettingsMock = TargetSettingsProviderMock(resolveTargetResult: .fake())
        isMicAuthorized = true
        createSut()
        var iterator = sut.unmetStream.makeAsyncIterator()

        #expect(await iterator.next() == [])
    }

    @Test
    mutating func refresh_micDenied_yieldsMicrophoneRequirement() async {
        targetSettingsMock = TargetSettingsProviderMock(resolveTargetResult: .fake())
        isMicAuthorized = false
        createSut()
        var iterator = sut.unmetStream.makeAsyncIterator()

        #expect(await iterator.next() == [.microphonePermission])
    }

    @Test
    mutating func refresh_noTarget_yieldsOutputDeviceRequirement() async {
        targetSettingsMock = TargetSettingsProviderMock(resolveTargetResult: nil)
        isMicAuthorized = true
        createSut()
        var iterator = sut.unmetStream.makeAsyncIterator()

        #expect(await iterator.next() == [.outputDevice])
    }

    @Test
    mutating func refresh_bothMissing_yieldsBoth() async {
        targetSettingsMock = TargetSettingsProviderMock(resolveTargetResult: nil)
        isMicAuthorized = false
        createSut()
        var iterator = sut.unmetStream.makeAsyncIterator()

        #expect(await iterator.next() == [.microphonePermission, .outputDevice])
    }

    @Test
    mutating func refresh_calledAgainWithoutChange_doesNotYieldDuplicate() async {
        targetSettingsMock = TargetSettingsProviderMock(resolveTargetResult: .fake())
        isMicAuthorized = true
        createSut()
        var iterator = sut.unmetStream.makeAsyncIterator()
        #expect(await iterator.next() == [])

        await sut.refresh()

        // No further yield expected. Trigger a change to confirm the iterator is
        // still alive and would receive a different value.
        await targetSettingsMock.setResolveTargetResult(nil)
        await sut.refresh()
        #expect(await iterator.next() == [.outputDevice])
    }
}
