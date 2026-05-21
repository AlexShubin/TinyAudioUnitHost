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
import Testing
@testable import TinyAudioUnitHost

@MainActor
@Suite
struct PresetsViewModelTests {
    var sessionMock: SessionManagerMock!
    var sut: PresetsViewModelType!

    init() {
        sessionMock = SessionManagerMock()
    }

    mutating func createSut() {
        sut = PresetsViewModel(session: sessionMock)
    }

    // MARK: - forwarded state

    @Test
    mutating func presets_forwardsSessionPresets() async {
        sessionMock.setPresets([Preset.fake(name: "a"), Preset.fake(name: "b")])
        createSut()

        #expect(sut.presets.map(\.name) == ["a", "b"])
    }

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
        sessionMock.setContent(.unmet([.outputDevice]))
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

    // MARK: - selected / deleteTapped / saveAsTapped (forwarding)

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

    @Test
    mutating func saveAsTapped_forwardsToSessionRequestSaveAs() async {
        createSut()

        await sut.accept(action: .saveAsTapped)

        #expect(sessionMock.calls == [.requestSaveAs])
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
    mutating func requestSaveAsDialogEvent_presentsSaveAsDialog() async {
        createSut()
        let sut = sut!

        sessionMock.emit(.requestSaveAsDialog)
        await awaitChange { sut.presentedPresetNameDialog == .saveAs }

        #expect(sut.presentedPresetNameDialog == .saveAs)
    }

    @Test
    mutating func requestProUpgradeEvent_bumpsOpenProWindowRequest() async {
        createSut()
        let sut = sut!

        sessionMock.emit(.requestProUpgrade)
        await awaitChange { sut.openProWindowRequest != nil }

        #expect(sut.openProWindowRequest != nil)
    }

    @Test
    mutating func savedEvent_isIgnored() async {
        createSut()
        let sut = sut!

        sessionMock.emit(.saved)
        // Cross-check by emitting a known event that does flip state.
        sessionMock.emit(.requestSaveAsDialog)
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
