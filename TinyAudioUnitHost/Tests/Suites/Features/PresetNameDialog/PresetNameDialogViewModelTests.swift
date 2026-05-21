//
//  PresetNameDialogViewModelTests.swift
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
struct PresetNameDialogViewModelTests {
    var sessionMock: SessionManagerMock!
    var validatorMock: PresetNameValidatorMock!
    var sut: PresetNameDialogViewModelType!

    init() {
        sessionMock = SessionManagerMock()
        validatorMock = PresetNameValidatorMock()
    }

    mutating func createSut(mode: PresetNameDialogMode = .saveAs) {
        sut = PresetNameDialogViewModel(
            mode: mode,
            session: sessionMock,
            validator: validatorMock
        )
    }

    // MARK: - initial state

    @Test
    mutating func init_saveAsMode_nameIsEmpty() {
        createSut(mode: .saveAs)

        #expect(sut.name == "")
    }

    @Test
    mutating func init_renameMode_namePrefilledFromCurrentName() {
        createSut(mode: .rename(currentName: "foo"))

        #expect(sut.name == "foo")
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
    mutating func errorMessage_duplicate_returnsHumanReadable() async {
        validatorMock.result = .duplicate
        createSut()

        await sut.accept(action: .nameChanged("foo"))

        #expect(sut.errorMessage == "A preset with that name already exists.")
    }

    @Test
    mutating func errorMessage_invalidCharacter_returnsHumanReadable() async {
        validatorMock.result = .invalidCharacter
        createSut()

        await sut.accept(action: .nameChanged("foo/bar"))

        #expect(sut.errorMessage == "Name can't contain /, :, or start with a dot.")
    }

    @Test
    mutating func errorMessage_empty_returnsNil() async {
        validatorMock.result = .empty
        createSut()

        await sut.accept(action: .nameChanged(""))

        #expect(sut.errorMessage == nil)
    }

    // MARK: - canCommit

    @Test
    mutating func canCommit_emptyName_isFalse() async {
        createSut()

        await sut.accept(action: .nameChanged(""))

        #expect(sut.canCommit == false)
    }

    @Test
    mutating func canCommit_whitespaceName_isFalse() async {
        createSut()

        await sut.accept(action: .nameChanged("   "))

        #expect(sut.canCommit == false)
    }

    @Test
    mutating func canCommit_validatorError_isFalse() async {
        validatorMock.result = .duplicate
        createSut()

        await sut.accept(action: .nameChanged("dupe"))

        #expect(sut.canCommit == false)
    }

    @Test
    mutating func canCommit_validNameNoError_isTrue() async {
        createSut()

        await sut.accept(action: .nameChanged("foo"))

        #expect(sut.canCommit == true)
    }

    // MARK: - nameChanged

    @Test
    mutating func nameChanged_callsValidatorWithCorrectMode_saveAs() async {
        createSut(mode: .saveAs)

        await sut.accept(action: .nameChanged("foo"))

        #expect(validatorMock.calls == [.validate(name: "foo", mode: .saveAs)])
    }

    @Test
    mutating func nameChanged_callsValidatorWithCorrectMode_rename() async {
        createSut(mode: .rename(currentName: "old"))

        await sut.accept(action: .nameChanged("new"))

        #expect(validatorMock.calls == [.validate(name: "new", mode: .rename(currentName: "old"))])
    }

    @Test
    mutating func nameChanged_updatesName() async {
        createSut()

        await sut.accept(action: .nameChanged("typed"))

        #expect(sut.name == "typed")
    }

    // MARK: - cancel

    @Test
    mutating func cancel_setsIsDismissed() async {
        createSut()

        await sut.accept(action: .cancel)

        #expect(sut.isDismissed == true)
    }

    @Test
    mutating func cancel_doesNotCallSession() async {
        createSut()

        await sut.accept(action: .cancel)

        #expect(sessionMock.calls.isEmpty)
    }

    // MARK: - commit

    @Test
    mutating func commit_validatorRejects_setsErrorAndStaysOpen() async {
        validatorMock.result = .duplicate
        createSut(mode: .saveAs)
        // type a name that the validator will reject on commit re-check
        validatorMock = PresetNameValidatorMock()  // reset call log
        createSut(mode: .saveAs)
        await sut.accept(action: .nameChanged("foo"))
        validatorMock.result = .duplicate

        await sut.accept(action: .commit)

        #expect(sut.errorMessage == "A preset with that name already exists.")
        #expect(sut.isDismissed == false)
        #expect(sessionMock.calls.isEmpty)
    }

    @Test
    mutating func commit_saveAs_validatorOk_callsSessionSaveAsNewPreset() async {
        createSut(mode: .saveAs)
        await sut.accept(action: .nameChanged("MyNew"))

        await sut.accept(action: .commit)

        #expect(sessionMock.calls == [.saveAsNewPreset(name: "MyNew")])
        #expect(sut.isDismissed == true)
    }

    @Test
    mutating func commit_rename_validatorOk_callsSessionRenamePreset() async {
        createSut(mode: .rename(currentName: "old"))
        await sut.accept(action: .nameChanged("new"))

        await sut.accept(action: .commit)

        #expect(sessionMock.calls == [.renamePreset(from: "old", to: "new")])
        #expect(sut.isDismissed == true)
    }
}
