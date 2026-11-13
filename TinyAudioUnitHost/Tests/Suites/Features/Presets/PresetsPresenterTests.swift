//
//  PresetsPresenterTests.swift
//  TinyAudioUnitHostTests
//
//  Created by Alex Shubin on 21.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioUnitsKit
import AudioUnitsKitTestSupport
import ChannelStripKit
import ChannelStripKitTestSupport
import PresetKit
import PresetKitTestSupport
import Testing
@testable import TinyAudioUnitHost

@MainActor
@Suite
struct PresetsPresenterTests {
    var channelStripSpy: ChannelStripModelSpy!
    var presetsSpy: PresetsModelSpy!
    var presetsNavigationSpy: PresetsNavigationModelSpy!
    var sut: PresetsPresenter!

    init() {
        channelStripSpy = ChannelStripModelSpy()
        presetsSpy = PresetsModelSpy()
        presetsNavigationSpy = PresetsNavigationModelSpy()
    }

    mutating func createSut() {
        sut = PresetsPresenter(
            channelStrip: channelStripSpy,
            presets: presetsSpy,
            presetsNavigation: presetsNavigationSpy
        )
    }

    // MARK: - forwarded state

    @Test
    mutating func activeName_forwardsPresetsActiveName() async {
        presetsSpy.activeName = "foo"
        createSut()

        #expect(sut.activeName == "foo")
    }

    @Test
    mutating func isInteractionDisabled_channelStripBusy_isTrue() async {
        channelStripSpy.isBusy = true
        createSut()

        #expect(sut.isInteractionDisabled == true)
    }

    @Test
    mutating func isInteractionDisabled_channelStripNotBusy_isFalse() async {
        createSut()

        #expect(sut.isInteractionDisabled == false)
    }

    @Test
    mutating func isSaveAsButtonDisabled_nothingLoaded_isTrue() async {
        createSut()

        #expect(sut.isSaveAsButtonDisabled == true)
    }

    @Test
    mutating func isSaveAsButtonDisabled_loaded_isFalse() async {
        channelStripSpy.slots = [.loaded(audioUnit: LoadedAudioUnit(component: .fake()), isBypassed: false)]
        createSut()

        #expect(sut.isSaveAsButtonDisabled == false)
    }

    // MARK: - names

    @Test
    mutating func names_forwardsEveryPresetName() async {
        presetsSpy.names = ["a", "b", "c"]
        createSut()

        #expect(sut.names == ["a", "b", "c"])
    }

    // MARK: - select / delete (forwarding)

    @Test
    mutating func select_forwardsToPresets() async {
        createSut()

        await sut.select(name: "foo")

        #expect(presetsSpy.calls == [.select(name: "foo")])
    }

    @Test
    mutating func delete_forwardsToPresets() {
        createSut()

        sut.delete(name: "foo")

        #expect(presetsSpy.calls == [.delete(name: "foo")])
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
