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
    var saveAsCommandSpy: BindableCommandSpy!
    var sut: PresetsPresenter!

    init() {
        sessionSpy = SessionModelSpy()
        purchasesSpy = PurchasesModelSpy()
        saveAsCommandSpy = BindableCommandSpy()
    }

    mutating func createSut() {
        sut = PresetsPresenter(
            session: sessionSpy,
            purchases: purchasesSpy,
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

        #expect(sut.presentedDialog == .saveAs)
        #expect(sut.isProWindowRequested == false)
    }

    @Test
    mutating func saveAs_freeBelowCap_presentsSaveAsDialog() {
        sessionSpy.presets = ["a"]
        createSut()

        sut.saveAs()

        #expect(sut.presentedDialog == .saveAs)
        #expect(sut.isProWindowRequested == false)
    }

    @Test
    mutating func saveAs_freeAtCap_requestsProWindow() {
        sessionSpy.presets = ["a", "b"]
        createSut()

        sut.saveAs()

        #expect(sut.presentedDialog == nil)
        #expect(sut.isProWindowRequested == true)
    }

    // MARK: - rename / dismiss dialog state

    @Test
    mutating func rename_presentsRenameDialog() {
        createSut()

        sut.rename(name: "foo")

        #expect(sut.presentedDialog == .rename(currentName: "foo"))
    }

    @Test
    mutating func presentedDialog_setNil_dismissesDialog() {
        createSut()
        sut.rename(name: "foo")

        sut.presentedDialog = nil

        #expect(sut.presentedDialog == nil)
    }

    @Test
    mutating func proWindowOpened_clearsRequest() {
        sessionSpy.presets = ["a", "b"]
        createSut()
        sut.saveAs()

        sut.proWindowOpened()

        #expect(sut.isProWindowRequested == false)
        #expect(sut.presentedDialog == nil)
    }

    // MARK: - save-as command

    @Test
    mutating func init_doesNotBindSaveAsCommand() async {
        createSut()

        #expect(saveAsCommandSpy.calls.isEmpty)
    }

    @Test
    mutating func task_bindsSaveAsCommand() async {
        createSut()

        sut.task()

        #expect(saveAsCommandSpy.calls == [.bind])
    }

    @Test
    mutating func saveAsCommand_freeBelowCap_presentsSaveAsDialog() async {
        sessionSpy.presets = ["a"]
        createSut()
        sut.task()

        saveAsCommandSpy.action?()

        #expect(sut.presentedDialog == .saveAs)
        #expect(sut.isProWindowRequested == false)
    }

    @Test
    mutating func saveAsCommand_freeAtCap_requestsProWindow() async {
        sessionSpy.presets = ["a", "b"]
        createSut()
        sut.task()

        saveAsCommandSpy.action?()

        #expect(sut.isProWindowRequested == true)
    }
}
