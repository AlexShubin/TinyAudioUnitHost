//
//  PresetNameDialogPresenterTests.swift
//  TinyAudioUnitHostTests
//
//  Created by Alex Shubin on 21.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioUnitsKit
import AudioUnitsKitTestSupport
import ChannelStripKit
import ChannelStripKitTestSupport
import Foundation
import PresetKit
import PresetKitTestSupport
import Testing
@testable import TinyAudioUnitHost

@MainActor
@Suite
struct PresetNameDialogPresenterTests {
    var channelStripSpy: ChannelStripModelSpy!
    var presetsSpy: PresetsModelSpy!
    var validatorSpy: PresetNameValidatorSpy!
    var sut: PresetNameDialogPresenter!

    init() {
        channelStripSpy = ChannelStripModelSpy()
        presetsSpy = PresetsModelSpy()
        validatorSpy = PresetNameValidatorSpy()
    }

    mutating func createSut(mode: PresetNameDialogMode = .saveAs) {
        sut = PresetNameDialogPresenter(
            mode: mode,
            channelStrip: channelStripSpy,
            presets: presetsSpy,
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
    mutating func cancel_doesNotCallPresets() {
        createSut()

        sut.cancel()

        #expect(presetsSpy.calls.isEmpty)
    }

    // MARK: - commit

    @Test
    mutating func commit_validatorRejects_keepsDialogAndPresets() {
        validatorSpy.result = .duplicate
        createSut(mode: .saveAs)
        sut.name = "foo"

        sut.commit()

        #expect(sut.isDismissed == false)
        #expect(presetsSpy.calls.isEmpty)
    }

    @Test
    mutating func commit_saveAs_savesChainAndDismisses() {
        let component = AudioUnitComponent.fake()
        channelStripSpy.slots = [.loaded(audioUnit: LoadedAudioUnit(component: component, fullState: Data([0x01])), isBypassed: false)]
        createSut(mode: .saveAs)
        sut.name = "MyNew"

        sut.commit()

        #expect(presetsSpy.calls == [.saveAsNew(name: "MyNew", preset: .fake(slots: [.fake(component: component, state: Data([0x01]))]))])
        #expect(sut.isDismissed == true)
    }

    @Test
    mutating func commit_saveAsNothingLoaded_dismissesWithoutSaving() {
        createSut(mode: .saveAs)
        sut.name = "MyNew"

        sut.commit()

        #expect(presetsSpy.calls.isEmpty)
        #expect(sut.isDismissed == true)
    }

    @Test
    mutating func commit_rename_renamesAndDismisses() {
        createSut(mode: .rename(currentName: "old"))
        sut.name = "new"

        sut.commit()

        #expect(presetsSpy.calls == [.rename(from: "old", to: "new")])
        #expect(sut.isDismissed == true)
    }
}
