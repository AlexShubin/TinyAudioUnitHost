//
//  PresetsPresenterTests.swift
//  TinyAudioUnitHostTests
//
//  Created by Alex Shubin on 21.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import SessionKit
import SessionKitTestSupport
import Testing
@testable import TinyAudioUnitHost

@MainActor
@Suite
struct PresetsPresenterTests {
    var sessionSpy: SessionModelSpy!
    var presetsNavigationSpy: PresetsNavigationModelSpy!
    var sut: PresetsPresenter!

    init() {
        sessionSpy = SessionModelSpy()
        presetsNavigationSpy = PresetsNavigationModelSpy()
    }

    mutating func createSut() {
        sut = PresetsPresenter(
            session: sessionSpy,
            presetsNavigation: presetsNavigationSpy
        )
    }

    // MARK: - forwarded state

    @Test
    mutating func activeName_forwardsSessionActivePresetName() async {
        sessionSpy.activePresetName = "foo"
        createSut()

        #expect(sut.activeName == "foo")
    }

    @Test
    mutating func isInteractionDisabled_sessionBusy_isTrue() async {
        sessionSpy.isBusy = true
        createSut()

        #expect(sut.isInteractionDisabled == true)
    }

    @Test
    mutating func isInteractionDisabled_sessionNotBusy_isFalse() async {
        createSut()

        #expect(sut.isInteractionDisabled == false)
    }

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

    // MARK: - presets

    @Test
    mutating func presets_forwardsEverySessionPreset() async {
        sessionSpy.presets = ["a", "b", "c"]
        createSut()

        #expect(sut.presets == ["a", "b", "c"])
    }

    // MARK: - select / delete (forwarding)

    @Test
    mutating func select_forwardsToSession() async {
        createSut()

        await sut.select(name: "foo")

        #expect(sessionSpy.calls == [.selectPreset(name: "foo")])
    }

    @Test
    mutating func delete_forwardsToSession() {
        createSut()

        sut.delete(name: "foo")

        #expect(sessionSpy.calls == [.deletePreset(name: "foo")])
    }

    // MARK: - name dialog

    @Test
    mutating func saveAs_presentsSaveAsDialog() {
        createSut()

        sut.saveAs()

        #expect(presetsNavigationSpy.presentedNameDialogMode == .saveAs)
    }

    @Test
    mutating func rename_presentsRenameDialog() {
        createSut()

        sut.rename(name: "foo")

        #expect(presetsNavigationSpy.presentedNameDialogMode == .rename(currentName: "foo"))
    }

    @Test
    mutating func presentedNameDialogMode_readsNavigation() {
        presetsNavigationSpy.presentedNameDialogMode = .saveAs
        createSut()

        #expect(sut.presentedNameDialogMode == .saveAs)
    }

    @Test
    mutating func presentedNameDialogMode_setNil_dismissesThroughNavigation() {
        presetsNavigationSpy.presentedNameDialogMode = .rename(currentName: "foo")
        createSut()

        sut.presentedNameDialogMode = nil

        #expect(presetsNavigationSpy.presentedNameDialogMode == nil)
    }
}
