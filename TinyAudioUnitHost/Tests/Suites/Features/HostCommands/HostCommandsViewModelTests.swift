//
//  HostCommandsViewModelTests.swift
//  TinyAudioUnitHostTests
//
//  Created by Alex Shubin on 21.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioUnitsKitTestSupport
import Foundation
import Testing
@testable import TinyAudioUnitHost

@MainActor
@Suite
struct HostCommandsViewModelTests {
    var sessionMock: SessionManagerMock!
    var sut: HostCommandsViewModelType!

    init() {
        sessionMock = SessionManagerMock()
    }

    mutating func createSut() {
        sut = HostCommandsViewModel(session: sessionMock)
    }

    // MARK: - actions

    @Test
    mutating func save_forwardsToSessionSaveCurrentPreset() async {
        createSut()

        await sut.accept(action: .save)

        #expect(sessionMock.calls == [.saveCurrentPreset])
    }

    @Test
    mutating func restore_forwardsToSessionRestoreActivePreset() async {
        createSut()

        await sut.accept(action: .restore)

        #expect(sessionMock.calls == [.restoreActivePreset])
    }

    @Test
    mutating func saveAs_forwardsToSessionRequestSaveAs() async {
        createSut()

        await sut.accept(action: .saveAs)

        #expect(sessionMock.calls == [.requestSaveAs])
    }

    // MARK: - isSaveButtonDisabled

    @Test
    mutating func isSaveButtonDisabled_noActive() async {
        sessionMock.setContent(.loaded(.fake()))
        sessionMock.setActiveName(nil)
        createSut()

        #expect(sut.isSaveButtonDisabled == true)
    }

    @Test
    mutating func isSaveButtonDisabled_activeButContentNotLoaded() async {
        sessionMock.setContent(.empty)
        sessionMock.setActiveName("foo")
        createSut()

        #expect(sut.isSaveButtonDisabled == true)
    }

    @Test
    mutating func isSaveButtonDisabled_activeAndLoaded_isFalse() async {
        sessionMock.setContent(.loaded(.fake()))
        sessionMock.setActiveName("foo")
        createSut()

        #expect(sut.isSaveButtonDisabled == false)
    }

    // MARK: - isRestoreButtonDisabled

    @Test
    mutating func isRestoreButtonDisabled_noActive() async {
        sessionMock.setActiveName(nil)
        createSut()

        #expect(sut.isRestoreButtonDisabled == true)
    }

    @Test
    mutating func isRestoreButtonDisabled_activeButContentLoading() async {
        sessionMock.setActiveName("foo")
        sessionMock.setContent(.loading)
        createSut()

        #expect(sut.isRestoreButtonDisabled == true)
    }

    @Test
    mutating func isRestoreButtonDisabled_activeAndContentEmpty_isFalse() async {
        sessionMock.setActiveName("foo")
        sessionMock.setContent(.empty)
        createSut()

        #expect(sut.isRestoreButtonDisabled == false)
    }

    // MARK: - isSaveAsButtonDisabled

    @Test
    mutating func isSaveAsButtonDisabled_contentNotLoaded_isTrue() async {
        sessionMock.setContent(.empty)
        createSut()

        #expect(sut.isSaveAsButtonDisabled == true)
    }

    @Test
    mutating func isSaveAsButtonDisabled_contentLoaded_isFalse() async {
        sessionMock.setContent(.loaded(.fake()))
        createSut()

        #expect(sut.isSaveAsButtonDisabled == false)
    }
}
