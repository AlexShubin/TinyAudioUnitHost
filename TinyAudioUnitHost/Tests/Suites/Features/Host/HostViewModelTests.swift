//
//  HostViewModelTests.swift
//  TinyAudioUnitHostTests
//
//  Created by Alex Shubin on 04.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioUnitsKit
import AudioUnitsKitTestSupport
import Foundation
import Observation
import PresetKit
import PresetKitTestSupport
import PurchasesKit
import PurchasesKitTestSupport
import Testing
@testable import TinyAudioUnitHost

@MainActor
@Suite
struct HostViewModelTests {
    var libraryMock: AudioUnitComponentsLibraryMock!
    var sessionMock: SessionManagerMock!
    var purchasesServiceMock: PurchasesServiceMock!
    var eventBusMock: SessionEventBusMock!
    var sut: HostViewModelType!

    init() {
        libraryMock = AudioUnitComponentsLibraryMock()
        sessionMock = SessionManagerMock()
        purchasesServiceMock = PurchasesServiceMock()
        eventBusMock = SessionEventBusMock()
    }

    mutating func createSut() {
        sut = HostViewModel(
            library: libraryMock,
            session: sessionMock,
            purchasesService: purchasesServiceMock,
            eventBus: eventBusMock
        )
    }

    // MARK: - task

    @Test
    mutating func task_groupsLibraryComponentsAlphabetically() async {
        libraryMock.components = [
            .fake(name: "Reverb", manufacturer: "Zoom"),
            .fake(name: "Dynamics", manufacturer: "Apple"),
            .fake(name: "Compressor", manufacturer: "Korn"),
        ]
        createSut()

        await sut.accept(action: .task)

        #expect(sut.groups.map(\.manufacturer) == ["Apple", "Korn", "Zoom"])
    }

    @Test
    mutating func task_startsSession() async {
        createSut()

        await sut.accept(action: .task)

        #expect(sessionMock.calls == [.start])
    }

    // MARK: - selected / save / restore (forwarding)

    @Test
    mutating func selected_forwardsToSessionLoadComponent() async {
        let component = AudioUnitComponent.fake(name: "Dynamics")
        createSut()

        await sut.accept(action: .selected(component))

        #expect(sessionMock.calls == [.loadComponent(component)])
    }

    @Test
    mutating func saveCurrentPreset_forwardsToSession() async {
        createSut()

        await sut.accept(action: .saveCurrentPreset)

        #expect(sessionMock.calls == [.saveCurrentPreset])
    }

    @Test
    mutating func restorePreset_forwardsToSession() async {
        createSut()

        await sut.accept(action: .restorePreset)

        #expect(sessionMock.calls == [.restoreActivePreset])
    }

    // MARK: - feedback from session events

    @Test
    mutating func savedEvent_setsFeedbackToSaved() async {
        createSut()
        let sut = sut!

        eventBusMock.post(.saved)
        await awaitChange { sut.feedback?.kind == .saved }

        #expect(sut.feedback?.kind == .saved)
    }

    @Test
    mutating func restoredEvent_setsFeedbackToRestored() async {
        createSut()
        let sut = sut!

        eventBusMock.post(.restored)
        await awaitChange { sut.feedback?.kind == .restored }

        #expect(sut.feedback?.kind == .restored)
    }

    @Test
    mutating func saveAsRequestedEvent_isIgnored() async {
        createSut()
        let sut = sut!

        eventBusMock.post(.saveAsRequested)
        // Cross-check by emitting a known event that does flip state.
        eventBusMock.post(.saved)
        await awaitChange { sut.feedback?.kind == .saved }

        #expect(sut.feedback?.kind == .saved)
    }

    @Test
    mutating func feedbackToastTimedOut_clearsFeedback() async {
        createSut()
        let sut = sut!
        eventBusMock.post(.saved)
        await awaitChange { sut.feedback != nil }

        await sut.accept(action: .feedbackToastAction(.timedOut))

        #expect(sut.feedback == nil)
    }

    // MARK: - isStarFilled

    @Test
    mutating func isStarFilled_defaultsToFalse() async {
        createSut()

        #expect(sut.isStarFilled == false)
    }

    @Test
    mutating func isStarFilled_followsPurchasesProStream() async {
        purchasesServiceMock = PurchasesServiceMock(isPro: true)
        createSut()
        let sut = sut!

        await awaitChange { sut.isStarFilled == true }

        #expect(sut.isStarFilled == true)
    }

    @Test
    mutating func isStarFilled_updatesWhenProBroadcastChanges() async {
        purchasesServiceMock = PurchasesServiceMock(isPro: false)
        createSut()
        let sut = sut!
        await awaitChange { sut.isStarFilled == false }

        await purchasesServiceMock.setIsPro(true)
        await awaitChange { sut.isStarFilled == true }

        #expect(sut.isStarFilled == true)
    }

    // MARK: - presetLabel

    @Test
    mutating func presetLabel_noActive_showsDash() async {
        sessionMock.setActiveName(nil)
        createSut()

        #expect(sut.presetLabel == "Preset: —")
    }

    @Test
    mutating func presetLabel_withActive_showsName() async {
        sessionMock.setActiveName("foo")
        createSut()

        #expect(sut.presetLabel == "Preset: foo")
    }

    // MARK: - audioUnitTitle

    @Test
    mutating func audioUnitTitle_loaded_returnsComponentName() async {
        let component = AudioUnitComponent.fake(name: "Reverb")
        let loaded = LoadedAudioUnit.fake(component: component)
        sessionMock.setContent(.loaded(loaded))
        createSut()

        #expect(sut.audioUnitTitle == "Reverb")
    }

    @Test
    mutating func audioUnitTitle_notLoaded_returnsChooseAudioUnit() async {
        sessionMock.setContent(.empty)
        createSut()

        #expect(sut.audioUnitTitle == "Choose Audio Unit")
    }

    // MARK: - button-disabled derivations

    @Test
    mutating func isAudioUnitPickerDisabled_whenContentIsLoading() async {
        sessionMock.setContent(.loading)
        createSut()

        #expect(sut.isAudioUnitPickerDisabled == true)
    }

    @Test
    mutating func isAudioUnitPickerDisabled_whenContentIsUnmet() async {
        sessionMock.setContent(.unmet([.microphonePermission]))
        createSut()

        #expect(sut.isAudioUnitPickerDisabled == true)
    }

    @Test
    mutating func isAudioUnitPickerDisabled_whenContentIsEmpty() async {
        sessionMock.setContent(.empty)
        createSut()

        #expect(sut.isAudioUnitPickerDisabled == false)
    }

    @Test
    mutating func isSaveButtonDisabled_noActive() async {
        let loaded = LoadedAudioUnit.fake()
        sessionMock.setContent(.loaded(loaded))
        sessionMock.setActiveName(nil)
        createSut()

        #expect(sut.isSaveButtonDisabled == true)
    }

    @Test
    mutating func isSaveButtonDisabled_activeButContentNotLoaded() async {
        sessionMock.setContent(.empty)
        sessionMock.setActiveName("foo")
        createSut()

        #expect(sut.isSaveButtonDisabled == true)
    }

    @Test
    mutating func isSaveButtonDisabled_activeAndLoaded_enabled() async {
        let loaded = LoadedAudioUnit.fake()
        sessionMock.setContent(.loaded(loaded))
        sessionMock.setActiveName("foo")
        createSut()

        #expect(sut.isSaveButtonDisabled == false)
    }

    @Test
    mutating func isRestoreButtonDisabled_noActive() async {
        sessionMock.setContent(.empty)
        sessionMock.setActiveName(nil)
        createSut()

        #expect(sut.isRestoreButtonDisabled == true)
    }

    @Test
    mutating func isRestoreButtonDisabled_activeAndLoading() async {
        sessionMock.setContent(.loading)
        sessionMock.setActiveName("foo")
        createSut()

        #expect(sut.isRestoreButtonDisabled == true)
    }

    @Test
    mutating func isRestoreButtonDisabled_activeAndFailed_enabled() async {
        sessionMock.setContent(.failed("oops"))
        sessionMock.setActiveName("foo")
        createSut()

        #expect(sut.isRestoreButtonDisabled == false)
    }

    // MARK: - Helpers

    private func awaitChange(_ predicate: () -> Bool) async {
        while !predicate() {
            await withCheckedContinuation { continuation in
                withObservationTracking {
                    _ = predicate()
                } onChange: {
                    continuation.resume()
                }
            }
        }
    }
}
