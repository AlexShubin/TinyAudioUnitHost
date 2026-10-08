//
//  PresetsPresenterTests.swift
//  TinyAudioUnitHostTests
//
//  Created by Alex Shubin on 21.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import Foundation
import PresetKit
import PresetKitTestSupport
import PurchasesKit
import PurchasesKitTestSupport
import Testing
@testable import TinyAudioUnitHost

@MainActor
@Suite
struct PresetsPresenterTests {
    var sessionSpy: SessionModelSpy!
    var purchasesSpy: PurchasesModelSpy!
    var navigationSpy: NavigationModelSpy!
    var saveAsCommandSpy: BindableCommandSpy!
    var sut: PresetsPresenterType!

    init() {
        sessionSpy = SessionModelSpy()
        purchasesSpy = PurchasesModelSpy()
        navigationSpy = NavigationModelSpy()
        saveAsCommandSpy = BindableCommandSpy()
    }

    mutating func createSut() {
        sut = PresetsPresenter(
            session: sessionSpy,
            purchases: purchasesSpy,
            navigation: navigationSpy,
            saveAsCommandBinder: saveAsCommandSpy
        )
    }

    // MARK: - forwarded state

    @Test
    mutating func activeName_forwardsSessionActiveName() async {
        sessionSpy.activeName = "foo"
        createSut()

        #expect(sut.activeName == "foo")
    }

    @Test
    mutating func isInteractionDisabled_contentLoading_isTrue() async {
        sessionSpy.content = .loading
        createSut()

        #expect(sut.isInteractionDisabled == true)
    }

    @Test
    mutating func isInteractionDisabled_contentUnmet_isTrue() async {
        sessionSpy.content = .unmet([.noOutputDevice])
        createSut()

        #expect(sut.isInteractionDisabled == true)
    }

    @Test
    mutating func isInteractionDisabled_contentLoaded_isFalse() async {
        sessionSpy.content = .loaded(.fake())
        createSut()

        #expect(sut.isInteractionDisabled == false)
    }

    @Test
    mutating func isSaveAsButtonDisabled_contentNotLoaded_isTrue() async {
        sessionSpy.content = .empty
        createSut()

        #expect(sut.isSaveAsButtonDisabled == true)
    }

    @Test
    mutating func isSaveAsButtonDisabled_contentLoaded_isFalse() async {
        sessionSpy.content = .loaded(.fake())
        createSut()

        #expect(sut.isSaveAsButtonDisabled == false)
    }

    // MARK: - presets (free-tier cap)

    @Test
    mutating func presets_freeUser_slicesToFirstTwo() async {
        sessionSpy.presets = ["a", "b", "c"]
        createSut()

        #expect(sut.presets == ["a", "b"])
    }

    @Test
    mutating func presets_proUser_returnsAll() async {
        purchasesSpy.state = .pro
        sessionSpy.presets = ["a", "b", "c"]
        createSut()

        #expect(sut.presets == ["a", "b", "c"])
    }

    // MARK: - selected / deleteTapped (forwarding)

    @Test
    mutating func select_forwardsToSession() async {
        createSut()

        await sut.select(name: "foo")

        #expect(sessionSpy.calls == [.selectPreset(name: "foo")])
    }

    @Test
    mutating func delete_forwardsToSession() {
        createSut()

        sut.delete(name: "foo")

        #expect(sessionSpy.calls == [.deletePreset(name: "foo")])
    }

    // MARK: - saveAsTapped: cap-and-decide

    @Test
    mutating func saveAs_pro_presentsSaveAsDialog() {
        purchasesSpy.state = .pro
        sessionSpy.presets = ["a", "b", "c"]
        createSut()

        sut.saveAs()

        #expect(navigationSpy.presetsDestination == .presetNameDialog(.saveAs))
        #expect(sut.presentedDialog == .saveAs)
        #expect(sut.isProWindowRequested == false)
    }

    @Test
    mutating func saveAs_freeBelowCap_presentsSaveAsDialog() {
        sessionSpy.presets = ["a"]
        createSut()

        sut.saveAs()

        #expect(navigationSpy.presetsDestination == .presetNameDialog(.saveAs))
        #expect(sut.presentedDialog == .saveAs)
        #expect(sut.isProWindowRequested == false)
    }

    @Test
    mutating func saveAs_freeAtCap_requestsProWindow() {
        sessionSpy.presets = ["a", "b"]
        createSut()

        sut.saveAs()

        #expect(navigationSpy.presetsDestination == .proWindow)
        #expect(sut.presentedDialog == nil)
        #expect(sut.isProWindowRequested == true)
    }

    // MARK: - rename / dismiss dialog state

    @Test
    mutating func rename_presentsRenameDialog() {
        createSut()

        sut.rename(name: "foo")

        #expect(navigationSpy.presetsDestination == .presetNameDialog(.rename(currentName: "foo")))
        #expect(sut.presentedDialog == .rename(currentName: "foo"))
    }

    @Test
    mutating func dismissDestination_clearsDestination() {
        createSut()
        navigationSpy.presetsDestination = .presetNameDialog(.rename(currentName: "foo"))

        sut.dismissDestination()

        #expect(navigationSpy.presetsDestination == nil)
        #expect(sut.presentedDialog == nil)
    }

    // MARK: - save-as command

    @Test
    mutating func init_bindsSaveAsCommand() async {
        createSut()

        #expect(saveAsCommandSpy.calls == [.bind])
    }

    @Test
    mutating func saveAsCommand_freeBelowCap_presentsSaveAsDialog() async {
        sessionSpy.presets = ["a"]
        createSut()

        saveAsCommandSpy.action?()

        #expect(navigationSpy.presetsDestination == .presetNameDialog(.saveAs))
        #expect(sut.presentedDialog == .saveAs)
        #expect(sut.isProWindowRequested == false)
    }

    @Test
    mutating func saveAsCommand_freeAtCap_opensProUpgrade() async {
        sessionSpy.presets = ["a", "b"]
        createSut()

        saveAsCommandSpy.action?()

        #expect(navigationSpy.presetsDestination == .proWindow)
    }

}
