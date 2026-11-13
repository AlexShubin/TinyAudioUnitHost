//
//  AppCommandsPresenterTests.swift
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
struct AppCommandsPresenterTests {
    var channelStripSpy: ChannelStripModelSpy!
    var presetsSpy: PresetsModelSpy!
    var presetsNavigationSpy: PresetsNavigationModelSpy!
    var sut: AppCommandsPresenter!

    init() {
        channelStripSpy = ChannelStripModelSpy()
        presetsSpy = PresetsModelSpy()
        presetsNavigationSpy = PresetsNavigationModelSpy()
    }

    mutating func createSut() {
        sut = AppCommandsPresenter(
            channelStrip: channelStripSpy,
            presets: presetsSpy,
            presetsNavigation: presetsNavigationSpy
        )
    }

    // MARK: - actions

    @Test
    mutating func savePreset_savesChainAsCurrentPreset() {
        let component = AudioUnitComponent.fake()
        channelStripSpy.slots = [.loaded(audioUnit: LoadedAudioUnit(component: component, fullState: Data([0x01])), isBypassed: false)]
        createSut()

        sut.savePreset()

        #expect(presetsSpy.calls == [.saveCurrent(preset: .fake(slots: [.fake(component: component, state: Data([0x01]))]))])
    }

    @Test
    mutating func savePreset_nothingLoaded_isNoOp() {
        createSut()

        sut.savePreset()

        #expect(presetsSpy.calls.isEmpty)
    }

    @Test
    mutating func restorePreset_forwardsToPresets() async {
        createSut()

        await sut.restorePreset()

        #expect(presetsSpy.calls == [.restoreActive])
    }

    @Test
    mutating func saveAsPreset_presentsSaveAsDialog() {
        createSut()

        sut.saveAsPreset()

        #expect(presetsNavigationSpy.presentedNameDialogMode == .saveAs)
        #expect(presetsSpy.calls.isEmpty)
    }

    // MARK: - isSaveButtonDisabled

    @Test
    mutating func isSaveButtonDisabled_noActive() async {
        channelStripSpy.slots = [.loaded(audioUnit: LoadedAudioUnit(component: .fake()), isBypassed: false)]
        createSut()

        #expect(sut.isSaveButtonDisabled == true)
    }

    @Test
    mutating func isSaveButtonDisabled_activeButNothingLoaded() async {
        presetsSpy.activeName = "foo"
        createSut()

        #expect(sut.isSaveButtonDisabled == true)
    }

    @Test
    mutating func isSaveButtonDisabled_activeAndLoaded_isFalse() async {
        presetsSpy.activeName = "foo"
        channelStripSpy.slots = [.loaded(audioUnit: LoadedAudioUnit(component: .fake()), isBypassed: false)]
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
        presetsSpy.activeName = "foo"
        channelStripSpy.isBusy = true
        createSut()

        #expect(sut.isRestoreButtonDisabled == true)
    }

    @Test
    mutating func isRestoreButtonDisabled_activeAndNotBusy_isFalse() async {
        presetsSpy.activeName = "foo"
        createSut()

        #expect(sut.isRestoreButtonDisabled == false)
    }

    // MARK: - isSaveAsButtonDisabled

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
}
