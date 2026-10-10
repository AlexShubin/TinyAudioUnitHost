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
    var sut: PresetNameDialogPresenter!

    init() {
        sessionSpy = SessionModelSpy()
        validatorSpy = PresetNameValidatorSpy()
    }

    mutating func createSut(mode: PresetNameDialogMode = .saveAs) {
        sut = PresetNameDialogPresenter(
            mode: mode,
            session: sessionSpy,
            validator: validatorSpy
        )
    }

    // MARK: - name

    @Test
    mutating func name_saveAs_startsEmpty() {
        createSut(mode: .saveAs)

        #expect(sut.name == "")
    }

    @Test
    mutating func name_rename_startsWithCurrentName() {
        createSut(mode: .rename(currentName: "foo"))

        #expect(sut.name == "foo")
    }

    @Test
    mutating func isDismissed_startsFalse() {
        createSut()

        #expect(sut.isDismissed == false)
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

        sut.name = "foo"

        #expect(sut.errorMessage == "A preset with that name already exists.")
    }

    @Test
    mutating func errorMessage_invalidCharacter_returnsHumanReadable() {
        validatorSpy.result = .invalidCharacter
        createSut()

        sut.name = "foo/bar"

        #expect(sut.errorMessage == "Name can't contain /, :, or start with a dot.")
    }

    @Test
    mutating func errorMessage_empty_returnsNil() {
        validatorSpy.result = .empty
        createSut()

        #expect(sut.errorMessage == nil)
    }

    @Test
    mutating func errorMessage_validatesWithMode_saveAs() {
        createSut(mode: .saveAs)
        sut.name = "foo"

        _ = sut.errorMessage

        #expect(validatorSpy.calls == [.validate(name: "foo", mode: .saveAs)])
    }

    @Test
    mutating func errorMessage_validatesWithMode_rename() {
        createSut(mode: .rename(currentName: "old"))
        sut.name = "new"

        _ = sut.errorMessage

        #expect(validatorSpy.calls == [.validate(name: "new", mode: .rename(currentName: "old"))])
    }

    // MARK: - canCommit

    @Test
    mutating func canCommit_validatorError_isFalse() {
        validatorSpy.result = .empty
        createSut()

        #expect(sut.canCommit == false)
    }

    @Test
    mutating func canCommit_validName_isTrue() {
        createSut()
        sut.name = "foo"

        #expect(sut.canCommit == true)
    }

    // MARK: - cancel

    @Test
    mutating func cancel_dismisses() {
        createSut()

        sut.cancel()

        #expect(sut.isDismissed == true)
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
        sut.name = "foo"

        sut.commit()

        #expect(sut.isDismissed == false)
        #expect(sessionSpy.calls.isEmpty)
    }

    @Test
    mutating func commit_saveAs_savesAndDismisses() {
        createSut(mode: .saveAs)
        sut.name = "MyNew"

        sut.commit()

        #expect(sessionSpy.calls == [.saveAsNewPreset(name: "MyNew")])
        #expect(sut.isDismissed == true)
    }

    @Test
    mutating func commit_rename_renamesAndDismisses() {
        createSut(mode: .rename(currentName: "old"))
        sut.name = "new"

        sut.commit()

        #expect(sessionSpy.calls == [.renamePreset(from: "old", to: "new")])
        #expect(sut.isDismissed == true)
    }
}
