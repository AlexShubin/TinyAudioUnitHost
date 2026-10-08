//
//  PresetNameDialogPresenterTests.swift
//  TinyAudioUnitHostTests
//
//  Created by Alex Shubin on 21.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import Foundation
import PresetKit
import PresetKitTestSupport
import Testing
@testable import TinyAudioUnitHost

@MainActor
@Suite
struct PresetNameDialogPresenterTests {
    var sessionSpy: SessionModelSpy!
    var validatorSpy: PresetNameValidatorSpy!
    var navigationSpy: NavigationModelSpy!
    var sut: PresetNameDialogPresenterType!

    init() {
        sessionSpy = SessionModelSpy()
        validatorSpy = PresetNameValidatorSpy()
        navigationSpy = NavigationModelSpy()
    }

    mutating func createSut(mode: PresetNameDialogMode = .saveAs) {
        navigationSpy.presetsDestination = .presetNameDialog(mode)
        sut = PresetNameDialogPresenter(
            mode: mode,
            session: sessionSpy,
            validator: validatorSpy,
            navigation: navigationSpy
        )
    }

    // MARK: - initialName

    @Test
    mutating func initialName_saveAs_isEmpty() {
        createSut(mode: .saveAs)

        #expect(sut.initialName == "")
    }

    @Test
    mutating func initialName_rename_isCurrentName() {
        createSut(mode: .rename(currentName: "foo"))

        #expect(sut.initialName == "foo")
    }

    // MARK: - commitLabel

    @Test
    mutating func commitLabel_saveAs_isSave() {
        createSut(mode: .saveAs)

        #expect(sut.commitLabel == "Save")
    }

    @Test
    mutating func commitLabel_rename_isRename() {
        createSut(mode: .rename(currentName: "foo"))

        #expect(sut.commitLabel == "Rename")
    }

    // MARK: - errorMessage

    @Test
    mutating func errorMessage_duplicate_returnsHumanReadable() {
        validatorSpy.result = .duplicate
        createSut()

        #expect(sut.errorMessage(for: "foo") == "A preset with that name already exists.")
    }

    @Test
    mutating func errorMessage_invalidCharacter_returnsHumanReadable() {
        validatorSpy.result = .invalidCharacter
        createSut()

        #expect(sut.errorMessage(for: "foo/bar") == "Name can't contain /, :, or start with a dot.")
    }

    @Test
    mutating func errorMessage_empty_returnsNil() {
        validatorSpy.result = .empty
        createSut()

        #expect(sut.errorMessage(for: "") == nil)
    }

    @Test
    mutating func errorMessage_validatesWithMode_saveAs() {
        createSut(mode: .saveAs)

        _ = sut.errorMessage(for: "foo")

        #expect(validatorSpy.calls == [.validate(name: "foo", mode: .saveAs)])
    }

    @Test
    mutating func errorMessage_validatesWithMode_rename() {
        createSut(mode: .rename(currentName: "old"))

        _ = sut.errorMessage(for: "new")

        #expect(validatorSpy.calls == [.validate(name: "new", mode: .rename(currentName: "old"))])
    }

    // MARK: - canCommit

    @Test
    mutating func canCommit_validatorError_isFalse() {
        validatorSpy.result = .empty
        createSut()

        #expect(sut.canCommit(name: "") == false)
    }

    @Test
    mutating func canCommit_validName_isTrue() {
        createSut()

        #expect(sut.canCommit(name: "foo") == true)
    }

    // MARK: - cancel

    @Test
    mutating func cancel_clearsDestination() {
        createSut()

        sut.cancel()

        #expect(navigationSpy.presetsDestination == nil)
    }

    @Test
    mutating func cancel_doesNotCallSession() {
        createSut()

        sut.cancel()

        #expect(sessionSpy.calls.isEmpty)
    }

    // MARK: - commit

    @Test
    mutating func commit_validatorRejects_keepsDialogAndSession() {
        validatorSpy.result = .duplicate
        createSut(mode: .saveAs)

        sut.commit(name: "foo")

        #expect(navigationSpy.presetsDestination == .presetNameDialog(.saveAs))
        #expect(sessionSpy.calls.isEmpty)
    }

    @Test
    mutating func commit_saveAs_savesAndClearsDestination() {
        createSut(mode: .saveAs)

        sut.commit(name: "MyNew")

        #expect(sessionSpy.calls == [.saveAsNewPreset(name: "MyNew")])
        #expect(navigationSpy.presetsDestination == nil)
    }

    @Test
    mutating func commit_rename_renamesAndClearsDestination() {
        createSut(mode: .rename(currentName: "old"))

        sut.commit(name: "new")

        #expect(sessionSpy.calls == [.renamePreset(from: "old", to: "new")])
        #expect(navigationSpy.presetsDestination == nil)
    }
}
