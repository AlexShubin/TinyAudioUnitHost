//
//  HostPresenterTests.swift
//  TinyAudioUnitHostTests
//
//  Created by Alex Shubin on 04.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioSettingsKit
import AudioSettingsKitTestSupport
import AudioUnitsKit
import AudioUnitsKitTestSupport
import Foundation
import ChannelStripKit
import ChannelStripKitTestSupport
import PresetKit
import PresetKitTestSupport
import PurchasesKit
import PurchasesKitTestSupport
import Testing
@testable import TinyAudioUnitHost

@MainActor
@Suite
struct HostPresenterTests {
    var channelStripSpy: ChannelStripModelSpy!
    var presetsSpy: PresetsModelSpy!
    var audioSettingsSpy: AudioSettingsModelSpy!
    var purchasesSpy: PurchasesModelSpy!
    var sut: HostPresenter!

    init() {
        channelStripSpy = ChannelStripModelSpy()
        presetsSpy = PresetsModelSpy()
        audioSettingsSpy = AudioSettingsModelSpy()
        purchasesSpy = PurchasesModelSpy()
    }

    mutating func createSut() {
        sut = HostPresenter(
            channelStrip: channelStripSpy,
            presets: presetsSpy,
            audioSettings: audioSettingsSpy,
            purchases: purchasesSpy
        )
    }

    // MARK: - savePreset

    @Test
    mutating func savePreset_nothingLoaded_isNoOp() {
        createSut()

        sut.savePreset()

        #expect(presetsSpy.calls.isEmpty)
    }

    @Test
    mutating func savePreset_busy_isNoOp() {
        channelStripSpy.slots = [.loaded(audioUnit: LoadedAudioUnit(component: .fake()), isBypassed: false)]
        channelStripSpy.isBusy = true
        createSut()

        sut.savePreset()

        #expect(presetsSpy.calls.isEmpty)
    }

    @Test
    mutating func savePreset_loadedPlugin_savesItsComponentAndState() {
        let component = AudioUnitComponent.fake()
        channelStripSpy.slots = [.loaded(audioUnit: LoadedAudioUnit(component: component, fullState: Data([0xBE, 0xEF])), isBypassed: false)]
        createSut()

        sut.savePreset()

        #expect(presetsSpy.calls == [.saveCurrent(preset: .fake(slots: [.fake(component: component, state: Data([0xBE, 0xEF]))]))])
    }

    @Test
    mutating func savePreset_wholeChain_savesGapsAndFailedPluginsWithTheirState() {
        let first = AudioUnitComponent.fake(name: "First")
        let missing = AudioUnitComponent.fake(id: .init(type: 1, subType: 2, manufacturer: 3), name: "Missing")
        channelStripSpy.slots = [
            .loaded(audioUnit: LoadedAudioUnit(component: first, fullState: Data([0xAA])), isBypassed: false),
            .empty,
            .failed(component: missing, state: Data([0x02]), isBypassed: true, message: "oops"),
        ]
        createSut()

        sut.savePreset()

        #expect(presetsSpy.calls == [.saveCurrent(preset: .fake(slots: [
            .fake(component: first, state: Data([0xAA])),
            nil,
            .fake(component: missing, state: Data([0x02]), isBypassed: true),
        ]))])
    }

    @Test
    mutating func savePreset_bypassedPlugin_savesBypass() {
        let component = AudioUnitComponent.fake()
        channelStripSpy.slots = [.loaded(audioUnit: LoadedAudioUnit(component: component, fullState: Data([0x01])), isBypassed: true)]
        createSut()

        sut.savePreset()

        #expect(presetsSpy.calls == [.saveCurrent(preset: .fake(slots: [.fake(component: component, state: Data([0x01]), isBypassed: true)]))])
    }

    // MARK: - restorePreset

    @Test
    mutating func restorePreset_forwardsToPresets() async {
        createSut()

        await sut.restorePreset()

        #expect(presetsSpy.calls == [.restoreActive])
    }

    // MARK: - feedback

    @Test
    mutating func feedback_nilWithoutPresetEvent() {
        createSut()

        #expect(sut.feedback == nil)
    }

    @Test
    mutating func feedback_savedEvent_projectsSaved() {
        let id = UUID()
        presetsSpy.event = .fake(id: id, kind: .saved)
        createSut()

        #expect(sut.feedback == FeedbackToastViewState(id: id, kind: .saved))
    }

    @Test
    mutating func feedback_restoredEvent_projectsRestored() {
        let id = UUID()
        presetsSpy.event = .fake(id: id, kind: .restored)
        createSut()

        #expect(sut.feedback == FeedbackToastViewState(id: id, kind: .restored))
    }

    @Test
    mutating func feedbackToastTimedOut_acknowledgesPresetEvent() {
        presetsSpy.event = .fake()
        createSut()

        sut.feedbackTimedOut()

        #expect(presetsSpy.calls == [.acknowledgeEvent])
    }

    // MARK: - isStarFilled

    @Test
    mutating func isStarFilled_defaultsToFalse() async {
        createSut()

        #expect(sut.isStarFilled == false)
    }

    @Test
    mutating func isStarFilled_whenPro() async {
        purchasesSpy.state = .pro
        createSut()

        #expect(sut.isStarFilled == true)
    }

    @Test
    mutating func isStarFilled_followsPurchasesState() async {
        createSut()
        #expect(sut.isStarFilled == false)

        purchasesSpy.state = .pro

        #expect(sut.isStarFilled == true)
    }

    // MARK: - presetLabel

    @Test
    mutating func presetLabel_noActive_showsDash() async {
        createSut()

        #expect(sut.presetLabel == "Preset: —")
    }

    @Test
    mutating func presetLabel_withActive_showsName() async {
        presetsSpy.activeName = "foo"
        createSut()

        #expect(sut.presetLabel == "Preset: foo")
    }

    // MARK: - button-disabled derivations

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
    mutating func isSaveButtonDisabled_activeButOnlyFailedSlots() async {
        presetsSpy.activeName = "foo"
        channelStripSpy.slots = [.failed(component: .fake(), state: nil, isBypassed: false, message: "oops")]
        createSut()

        #expect(sut.isSaveButtonDisabled == true)
    }

    @Test
    mutating func isSaveButtonDisabled_activeButBusy() async {
        presetsSpy.activeName = "foo"
        channelStripSpy.slots = [.loaded(audioUnit: LoadedAudioUnit(component: .fake()), isBypassed: false), .loading(component: .fake())]
        channelStripSpy.isBusy = true
        createSut()

        #expect(sut.isSaveButtonDisabled == true)
    }

    @Test
    mutating func isSaveButtonDisabled_activeAndLaterSlotLoaded_enabled() async {
        presetsSpy.activeName = "foo"
        channelStripSpy.slots = [.empty, .loaded(audioUnit: LoadedAudioUnit(component: .fake()), isBypassed: false)]
        createSut()

        #expect(sut.isSaveButtonDisabled == false)
    }

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
    mutating func isRestoreButtonDisabled_activeAndNotBusy_enabled() async {
        presetsSpy.activeName = "foo"
        createSut()

        #expect(sut.isRestoreButtonDisabled == false)
    }

    // MARK: - content

    @Test
    mutating func content_setupChecking_isLoading() async {
        createSut()

        #expect(sut.content == .loading)
    }

    @Test
    mutating func content_setupUnmet_projectsRequirements() async {
        audioSettingsSpy.setup = .unmet([.microphonePermission])
        createSut()

        #expect(sut.content == .unmet([.microphonePermission]))
    }

    @Test
    mutating func content_noSlotAtSelection_isEmpty() async {
        audioSettingsSpy.setup = .met
        createSut()

        #expect(sut.content == .empty)
    }

    @Test
    mutating func content_selectedSlotLoading_isLoading() async {
        audioSettingsSpy.setup = .met
        channelStripSpy.slots = [.loading(component: .fake())]
        createSut()

        #expect(sut.content == .loading)
    }

    @Test
    mutating func content_selectedSlotFailed_projectsMessage() async {
        audioSettingsSpy.setup = .met
        channelStripSpy.slots = [.failed(component: .fake(), state: nil, isBypassed: false, message: "oops")]
        createSut()

        #expect(sut.content == .failed("oops"))
    }

    @Test
    mutating func content_showsSlotAtSelectedIndex() async {
        let first = LoadedAudioUnit(component: .fake())
        let second = LoadedAudioUnit(component: .fake())
        audioSettingsSpy.setup = .met
        channelStripSpy.slots = [.loaded(audioUnit: first, isBypassed: false), .loaded(audioUnit: second, isBypassed: false)]
        channelStripSpy.selectedIndex = 1
        createSut()

        #expect(sut.content == .loaded(second))
    }
}
