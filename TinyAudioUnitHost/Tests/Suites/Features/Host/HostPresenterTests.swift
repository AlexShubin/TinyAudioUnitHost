//
//  HostPresenterTests.swift
//  TinyAudioUnitHostTests
//
//  Created by Alex Shubin on 04.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

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
    var librarySpy: AudioUnitComponentsLibrarySpy!
    var sessionSpy: SessionModelSpy!
    var purchasesSpy: PurchasesModelSpy!
    var sut: HostPresenter!

    init() {
        librarySpy = AudioUnitComponentsLibrarySpy()
        sessionSpy = SessionModelSpy()
        purchasesSpy = PurchasesModelSpy()
    }

    mutating func createSut() {
        sut = HostPresenter(
            library: librarySpy,
            session: sessionSpy,
            purchases: purchasesSpy
        )
    }

    // MARK: - groups

    @Test
    mutating func groups_libraryComponentsByManufacturerAlphabetically() {
        librarySpy.components = [
            .fake(name: "Reverb", manufacturer: "Zoom"),
            .fake(name: "Dynamics", manufacturer: "Apple"),
            .fake(name: "Compressor", manufacturer: "Korn"),
        ]
        createSut()

        #expect(sut.groups.map(\.manufacturer) == ["Apple", "Korn", "Zoom"])
    }

    // MARK: - start / select / save / restore (forwarding)

    @Test
    mutating func task_startsSession() async {
        createSut()

        await sut.task()

        #expect(sessionSpy.calls == [.start])
    }

    @Test
    mutating func select_forwardsToSessionLoadComponent() async {
        let component = AudioUnitComponent.fake(name: "Dynamics")
        createSut()

        await sut.select(component)

        #expect(sessionSpy.calls == [.loadComponent(component)])
    }

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
        sessionSpy.activeName = nil
        createSut()

        #expect(sut.presetLabel == "Preset: —")
    }

    @Test
    mutating func presetLabel_withActive_showsName() async {
        sessionSpy.activeName = "foo"
        createSut()

        #expect(sut.presetLabel == "Preset: foo")
    }

    // MARK: - audioUnitTitle

    @Test
    mutating func audioUnitTitle_loaded_returnsComponentName() async {
        let component = AudioUnitComponent.fake(name: "Reverb")
        let loaded = LoadedAudioUnit.fake(component: component)
        sessionSpy.content = .loaded(loaded)
        createSut()

        #expect(sut.audioUnitTitle == "Reverb")
    }

    @Test
    mutating func audioUnitTitle_notLoaded_returnsChooseAudioUnit() async {
        sessionSpy.content = .empty
        createSut()

        #expect(sut.audioUnitTitle == "Choose Audio Unit")
    }

    // MARK: - button-disabled derivations

    @Test
    mutating func isAudioUnitPickerDisabled_whenContentIsLoading() async {
        sessionSpy.content = .loading
        createSut()

        #expect(sut.isAudioUnitPickerDisabled == true)
    }

    @Test
    mutating func isAudioUnitPickerDisabled_whenContentIsUnmet() async {
        sessionSpy.content = .unmet([.microphonePermission])
        createSut()

        #expect(sut.isAudioUnitPickerDisabled == true)
    }

    @Test
    mutating func isAudioUnitPickerDisabled_whenContentIsEmpty() async {
        sessionSpy.content = .empty
        createSut()

        #expect(sut.isAudioUnitPickerDisabled == false)
    }

    @Test
    mutating func isSaveButtonDisabled_noActive() async {
        let loaded = LoadedAudioUnit.fake()
        sessionSpy.content = .loaded(loaded)
        sessionSpy.activeName = nil
        createSut()

        #expect(sut.isSaveButtonDisabled == true)
    }

    @Test
    mutating func isSaveButtonDisabled_activeButContentNotLoaded() async {
        sessionSpy.content = .empty
        sessionSpy.activeName = "foo"
        createSut()

        #expect(sut.isSaveButtonDisabled == true)
    }

    @Test
    mutating func isSaveButtonDisabled_activeAndLoaded_enabled() async {
        let loaded = LoadedAudioUnit.fake()
        sessionSpy.content = .loaded(loaded)
        sessionSpy.activeName = "foo"
        createSut()

        #expect(sut.isSaveButtonDisabled == false)
    }

    @Test
    mutating func isRestoreButtonDisabled_noActive() async {
        sessionSpy.content = .empty
        sessionSpy.activeName = nil
        createSut()

        #expect(sut.isRestoreButtonDisabled == true)
    }

    @Test
    mutating func isRestoreButtonDisabled_activeAndLoading() async {
        sessionSpy.content = .loading
        sessionSpy.activeName = "foo"
        createSut()

        #expect(sut.isRestoreButtonDisabled == true)
    }

    @Test
    mutating func isRestoreButtonDisabled_activeAndFailed_enabled() async {
        sessionSpy.content = .failed("oops")
        sessionSpy.activeName = "foo"
        createSut()

        #expect(sut.isRestoreButtonDisabled == false)
    }

}
