//
//  AppCommandsPresenterTests.swift
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
struct AppCommandsPresenterTests {
    var sessionSpy: SessionModelSpy!
    var saveAsCommandSpy: BindableCommandSpy!
    var sut: AppCommandsPresenter!

    init() {
        sessionSpy = SessionModelSpy()
        saveAsCommandSpy = BindableCommandSpy()
    }

    mutating func createSut() {
        sut = AppCommandsPresenter(session: sessionSpy, saveAsCommand: saveAsCommandSpy)
    }

    // MARK: - actions

    @Test
    mutating func savePreset_forwardsToSession() {
        createSut()

        sut.savePreset()

        #expect(sessionSpy.calls == [.saveCurrentPreset])
    }

    @Test
    mutating func restorePreset_forwardsToSession() async {
        createSut()

        await sut.restorePreset()

        #expect(sessionSpy.calls == [.restoreActivePreset])
    }

    @Test
    mutating func saveAsPreset_executesSaveAsCommand() {
        createSut()

        sut.saveAsPreset()

        #expect(saveAsCommandSpy.calls == [.execute])
        #expect(sessionSpy.calls.isEmpty)
    }

    // MARK: - isSaveButtonDisabled

    @Test
    mutating func isSaveButtonDisabled_noActive() async {
        sessionSpy.content = .loaded(.fake())
        sessionSpy.activeName = nil
        createSut()

        #expect(sut.isSaveButtonDisabled == true)
    }

    @Test
    mutating func isSaveButtonDisabled_activeButContentNotLoaded() async {
        sessionSpy.content = .empty
        sessionSpy.activeName = "foo"
        createSut()

        #expect(sut.isSaveButtonDisabled == true)
    }

    @Test
    mutating func isSaveButtonDisabled_activeAndLoaded_isFalse() async {
        sessionSpy.content = .loaded(.fake())
        sessionSpy.activeName = "foo"
        createSut()

        #expect(sut.isSaveButtonDisabled == false)
    }

    // MARK: - isRestoreButtonDisabled

    @Test
    mutating func isRestoreButtonDisabled_noActive() async {
        sessionSpy.activeName = nil
        createSut()

        #expect(sut.isRestoreButtonDisabled == true)
    }

    @Test
    mutating func isRestoreButtonDisabled_activeButContentLoading() async {
        sessionSpy.activeName = "foo"
        sessionSpy.content = .loading
        createSut()

        #expect(sut.isRestoreButtonDisabled == true)
    }

    @Test
    mutating func isRestoreButtonDisabled_activeAndContentEmpty_isFalse() async {
        sessionSpy.activeName = "foo"
        sessionSpy.content = .empty
        createSut()

        #expect(sut.isRestoreButtonDisabled == false)
    }

    // MARK: - isSaveAsButtonDisabled

    @Test
    mutating func isSaveAsButtonDisabled_contentNotLoaded_isTrue() async {
        sessionSpy.content = .empty
        createSut()

        #expect(sut.isSaveAsButtonDisabled == true)
    }

    @Test
    mutating func isSaveAsButtonDisabled_contentLoaded_isFalse() async {
        sessionSpy.content = .loaded(.fake())
        createSut()

        #expect(sut.isSaveAsButtonDisabled == false)
    }
}
