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
import PresetKit
import PresetKitTestSupport
import PurchasesKit
import PurchasesKitTestSupport
import Testing
@testable import TinyAudioUnitHost

@MainActor
@Suite
struct HostPresenterTests {
    var sessionSpy: SessionModelSpy!
    var audioSettingsSpy: AudioSettingsModelSpy!
    var purchasesSpy: PurchasesModelSpy!
    var sut: HostPresenter!

    init() {
        sessionSpy = SessionModelSpy()
        audioSettingsSpy = AudioSettingsModelSpy()
        purchasesSpy = PurchasesModelSpy()
    }

    mutating func createSut() {
        sut = HostPresenter(
            session: sessionSpy,
            audioSettings: audioSettingsSpy,
            purchases: purchasesSpy
        )
    }

    // MARK: - save / restore (forwarding)

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

    // MARK: - feedback from session preset events

    @Test
    mutating func feedback_nilWithoutPresetEvent() {
        createSut()

        #expect(sut.feedback == nil)
    }

    @Test
    mutating func feedback_savedEvent_projectsSaved() {
        let id = UUID()
        sessionSpy.presetEvent = PresetEvent(id: id, kind: .saved)
        createSut()

        #expect(sut.feedback == FeedbackToastViewState(id: id, kind: .saved))
    }

    @Test
    mutating func feedback_restoredEvent_projectsRestored() {
        let id = UUID()
        sessionSpy.presetEvent = PresetEvent(id: id, kind: .restored)
        createSut()

        #expect(sut.feedback == FeedbackToastViewState(id: id, kind: .restored))
    }

    @Test
    mutating func feedbackToastTimedOut_acknowledgesPresetEvent() {
        sessionSpy.presetEvent = PresetEvent(id: UUID(), kind: .saved)
        createSut()

        sut.feedbackTimedOut()

        #expect(sessionSpy.calls == [.acknowledgePresetEvent])
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
        sessionSpy.activePresetName = "foo"
        createSut()

        #expect(sut.presetLabel == "Preset: foo")
    }

    // MARK: - button-disabled derivations

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
    mutating func isSaveButtonDisabled_activeAndCanSave_enabled() async {
        sessionSpy.activePresetName = "foo"
        sessionSpy.canSavePreset = true
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
        sessionSpy.activePresetName = "foo"
        sessionSpy.isBusy = true
        createSut()

        #expect(sut.isRestoreButtonDisabled == true)
    }

    @Test
    mutating func isRestoreButtonDisabled_activeAndNotBusy_enabled() async {
        sessionSpy.activePresetName = "foo"
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
        sessionSpy.slots = [.loading(component: .fake())]
        createSut()

        #expect(sut.content == .loading)
    }

    @Test
    mutating func content_selectedSlotFailed_projectsMessage() async {
        audioSettingsSpy.setup = .met
        sessionSpy.slots = [.failed(component: .fake(), state: nil, isBypassed: false, message: "oops")]
        createSut()

        #expect(sut.content == .failed("oops"))
    }

    @Test
    mutating func content_showsSlotAtSelectedIndex() async {
        let first = LoadedAudioUnit(component: .fake())
        let second = LoadedAudioUnit(component: .fake())
        audioSettingsSpy.setup = .met
        sessionSpy.slots = [.loaded(audioUnit: first, isBypassed: false), .loaded(audioUnit: second, isBypassed: false)]
        sessionSpy.selectedIndex = 1
        createSut()

        #expect(sut.content == .loaded(second))
    }
}
