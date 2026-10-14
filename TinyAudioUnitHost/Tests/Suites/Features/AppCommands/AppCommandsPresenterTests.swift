//
//  AppCommandsPresenterTests.swift
//  TinyAudioUnitHostTests
//
//  Created by Alex Shubin on 21.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioUnitsKit
import AudioUnitsKitTestSupport
import Foundation
import SessionKit
import SessionKitTestSupport
import Testing
@testable import TinyAudioUnitHost

@MainActor
@Suite
struct AppCommandsPresenterTests {
    var sessionSpy: SessionModelSpy!
    var presetsNavigationSpy: PresetsNavigationModelSpy!
    var sut: AppCommandsPresenter!

    init() {
        sessionSpy = SessionModelSpy()
        presetsNavigationSpy = PresetsNavigationModelSpy()
    }

    mutating func createSut() {
        sut = AppCommandsPresenter(session: sessionSpy, presetsNavigation: presetsNavigationSpy)
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
    mutating func saveAsPreset_presentsSaveAsDialog() {
        createSut()

        sut.saveAsPreset()

        #expect(presetsNavigationSpy.presentedNameDialogMode == .saveAs)
        #expect(sessionSpy.calls.isEmpty)
    }

    // MARK: - isSaveButtonDisabled

    @Test
    mutating func isSaveButtonDisabled_noActive() async {
        sessionSpy.canSavePreset = true
        createSut()

        #expect(sut.isSaveButtonDisabled == true)
    }

    @Test
    mutating func isSaveButtonDisabled_activeButCannotSave() async {
        sessionSpy.activePresetName = "foo"
        createSut()

        #expect(sut.isSaveButtonDisabled == true)
    }

    @Test
    mutating func isSaveButtonDisabled_activeAndCanSave_isFalse() async {
        sessionSpy.activePresetName = "foo"
        sessionSpy.canSavePreset = true
        createSut()

        #expect(sut.isSaveButtonDisabled == false)
    }

    // MARK: - isRestoreButtonDisabled

    @Test
    mutating func isRestoreButtonDisabled_noActive() async {
        createSut()

        #expect(sut.isRestoreButtonDisabled == true)
    }

    @Test
    mutating func isRestoreButtonDisabled_activeButBusy() async {
        sessionSpy.activePresetName = "foo"
        sessionSpy.isBusy = true
        createSut()

        #expect(sut.isRestoreButtonDisabled == true)
    }

    @Test
    mutating func isRestoreButtonDisabled_activeAndNotBusy_isFalse() async {
        sessionSpy.activePresetName = "foo"
        createSut()

        #expect(sut.isRestoreButtonDisabled == false)
    }

    // MARK: - isSaveAsButtonDisabled

    @Test
    mutating func isSaveAsButtonDisabled_cannotSave_isTrue() async {
        createSut()

        #expect(sut.isSaveAsButtonDisabled == true)
    }

    @Test
    mutating func isSaveAsButtonDisabled_canSave_isFalse() async {
        sessionSpy.canSavePreset = true
        createSut()

        #expect(sut.isSaveAsButtonDisabled == false)
    }
}
