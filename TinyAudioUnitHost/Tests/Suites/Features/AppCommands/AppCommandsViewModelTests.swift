//
//  AppCommandsViewModelTests.swift
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
struct AppCommandsViewModelTests {
    var sessionMock: SessionManagerMock!
    var saveAsCommandMock: BindableCommandMock!
    var sut: AppCommandsViewModelType!

    init() {
        sessionMock = SessionManagerMock()
        saveAsCommandMock = BindableCommandMock()
    }

    mutating func createSut() {
        sut = AppCommandsViewModel(session: sessionMock, saveAsCommand: saveAsCommandMock)
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
    mutating func saveAs_executesSaveAsCommand() async {
        createSut()

        await sut.accept(action: .saveAs)

        #expect(saveAsCommandMock.calls == [.execute])
        #expect(sessionMock.calls.isEmpty)
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
