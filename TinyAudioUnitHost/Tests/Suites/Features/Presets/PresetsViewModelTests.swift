//
//  PresetsViewModelTests.swift
//  TinyAudioUnitHostTests
//
//  Created by Alex Shubin on 21.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

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
struct PresetsViewModelTests {
    var sessionMock: SessionManagerMock!
    var purchasesServiceMock: PurchasesServiceMock!
    var eventBusMock: SessionEventBusMock!
    var sut: PresetsViewModelType!

    init() {
        sessionMock = SessionManagerMock()
        purchasesServiceMock = PurchasesServiceMock()
        eventBusMock = SessionEventBusMock()
    }

    mutating func createSut() {
        sut = PresetsViewModel(
            session: sessionMock,
            purchasesService: purchasesServiceMock,
            eventBus: eventBusMock
        )
    }

    // MARK: - forwarded state

    @Test
    mutating func activeName_forwardsSessionActiveName() async {
        sessionMock.setActiveName("foo")
        createSut()

        #expect(sut.activeName == "foo")
    }

    @Test
    mutating func isInteractionDisabled_contentLoading_isTrue() async {
        sessionMock.setContent(.loading)
        createSut()

        #expect(sut.isInteractionDisabled == true)
    }

    @Test
    mutating func isInteractionDisabled_contentUnmet_isTrue() async {
        sessionMock.setContent(.unmet([.noOutputDevice]))
        createSut()

        #expect(sut.isInteractionDisabled == true)
    }

    @Test
    mutating func isInteractionDisabled_contentLoaded_isFalse() async {
        sessionMock.setContent(.loaded(.fake()))
        createSut()

        #expect(sut.isInteractionDisabled == false)
    }

    @Test
    mutating func isSaveAsButtonDisabled_contentNotLoaded_isTrue() async {
        sessionMock.setContent(.empty)
        createSut()

        #expect(sut.isSaveAsButtonDisabled == true)
    }

    @Test
    mutating func isSaveAsButtonDisabled_contentLoaded_isFalse() async {
        sessionMock.setContent(.loaded(.fake()))
        createSut()

        #expect(sut.isSaveAsButtonDisabled == false)
    }

    // MARK: - presets (free-tier cap)

    @Test
    mutating func presets_freeUser_slicesToFirstTwo() async {
        sessionMock.setPresets([
            Preset.fake(name: "a"),
            Preset.fake(name: "b"),
            Preset.fake(name: "c"),
        ])
        createSut()

        #expect(sut.presets.map(\.name) == ["a", "b"])
    }

    @Test
    mutating func presets_proUser_returnsAll() async {
        purchasesServiceMock = PurchasesServiceMock(isPro: true)
        sessionMock.setPresets([
            Preset.fake(name: "a"),
            Preset.fake(name: "b"),
            Preset.fake(name: "c"),
        ])
        createSut()
        let sut = sut!
        await awaitChange { sut.presets.count == 3 }

        #expect(sut.presets.map(\.name) == ["a", "b", "c"])
    }

    // MARK: - selected / deleteTapped (forwarding)

    @Test
    mutating func selected_forwardsToSession() async {
        createSut()

        await sut.accept(action: .selected(name: "foo"))

        #expect(sessionMock.calls == [.selectPreset(name: "foo")])
    }

    @Test
    mutating func deleteTapped_forwardsToSession() async {
        createSut()

        await sut.accept(action: .deleteTapped(name: "foo"))

        #expect(sessionMock.calls == [.deletePreset(name: "foo")])
    }

    // MARK: - saveAsTapped: cap-and-decide

    @Test
    mutating func saveAsTapped_pro_presentsSaveAsDialog() async {
        purchasesServiceMock = PurchasesServiceMock(isPro: true)
        sessionMock.setPresets([Preset.fake(name: "a"), Preset.fake(name: "b"), Preset.fake(name: "c")])
        createSut()
        let sut = sut!
        await awaitChange { sut.presets.count == 3 }

        await sut.accept(action: .saveAsTapped)

        #expect(sut.presentedPresetNameDialog == .saveAs)
        #expect(sut.openProWindowRequest == nil)
    }

    @Test
    mutating func saveAsTapped_freeBelowCap_presentsSaveAsDialog() async {
        sessionMock.setPresets([Preset.fake(name: "a")])
        createSut()

        await sut.accept(action: .saveAsTapped)

        #expect(sut.presentedPresetNameDialog == .saveAs)
        #expect(sut.openProWindowRequest == nil)
    }

    @Test
    mutating func saveAsTapped_freeAtCap_opensProUpgrade() async {
        sessionMock.setPresets([Preset.fake(name: "a"), Preset.fake(name: "b")])
        createSut()

        await sut.accept(action: .saveAsTapped)

        #expect(sut.presentedPresetNameDialog == nil)
        #expect(sut.openProWindowRequest != nil)
    }

    // MARK: - rename / dismiss dialog state

    @Test
    mutating func renameTapped_setsPresentedDialogToRename() async {
        createSut()

        await sut.accept(action: .renameTapped(name: "foo"))

        #expect(sut.presentedPresetNameDialog == .rename(currentName: "foo"))
    }

    @Test
    mutating func dismissDialog_clearsPresentedDialog() async {
        createSut()
        await sut.accept(action: .renameTapped(name: "foo"))

        await sut.accept(action: .dismissDialog)

        #expect(sut.presentedPresetNameDialog == nil)
    }

    // MARK: - session events

    @Test
    mutating func saveAsRequestedEvent_freeBelowCap_presentsSaveAsDialog() async {
        sessionMock.setPresets([Preset.fake(name: "a")])
        createSut()
        let sut = sut!

        eventBusMock.post(.saveAsRequested)
        await awaitChange { sut.presentedPresetNameDialog == .saveAs }

        #expect(sut.presentedPresetNameDialog == .saveAs)
    }

    @Test
    mutating func saveAsRequestedEvent_freeAtCap_opensProUpgrade() async {
        sessionMock.setPresets([Preset.fake(name: "a"), Preset.fake(name: "b")])
        createSut()
        let sut = sut!

        eventBusMock.post(.saveAsRequested)
        await awaitChange { sut.openProWindowRequest != nil }

        #expect(sut.openProWindowRequest != nil)
        #expect(sut.presentedPresetNameDialog == nil)
    }

    @Test
    mutating func savedEvent_isIgnored() async {
        sessionMock.setPresets([Preset.fake(name: "a")])
        createSut()
        let sut = sut!

        eventBusMock.post(.saved)
        // Cross-check by emitting a known event that does flip state.
        eventBusMock.post(.saveAsRequested)
        await awaitChange { sut.presentedPresetNameDialog == .saveAs }

        #expect(sut.presentedPresetNameDialog == .saveAs)
        #expect(sut.openProWindowRequest == nil)
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
