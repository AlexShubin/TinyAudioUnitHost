//
//  ChannelStripPresenterTests.swift
//  TinyAudioUnitHostTests
//
//  Created by Alex Shubin on 11.10.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioSettingsKit
import AudioSettingsKitTestSupport
import AudioUnitsKit
import AudioUnitsKitTestSupport
import PurchasesKit
import PurchasesKitTestSupport
import Testing
@testable import TinyAudioUnitHost

@MainActor
@Suite
struct ChannelStripPresenterTests {
    var librarySpy: AudioUnitComponentsLibrarySpy!
    var sessionSpy: SessionModelSpy!
    var audioSettingsSpy: AudioSettingsModelSpy!
    var purchasesSpy: PurchasesModelSpy!
    var sut: ChannelStripPresenter!

    init() {
        librarySpy = AudioUnitComponentsLibrarySpy()
        sessionSpy = SessionModelSpy()
        audioSettingsSpy = AudioSettingsModelSpy()
        purchasesSpy = PurchasesModelSpy()
    }

    mutating func createSut() {
        sut = ChannelStripPresenter(
            library: librarySpy,
            session: sessionSpy,
            audioSettings: audioSettingsSpy,
            purchases: purchasesSpy
        )
    }

    // MARK: - sourceTitle

    @Test
    mutating func sourceTitle_instrumentInFirstSlot_isInstrument() {
        sessionSpy.slots = [.loaded(audioUnit: LoadedAudioUnit(component: Self.instrument), isBypassed: false)]
        createSut()

        #expect(sut.sourceTitle == "Instrument")
    }

    @Test
    mutating func sourceTitle_effectInFirstSlot_isInput() {
        sessionSpy.slots = [.loading(component: Self.effect)]
        createSut()

        #expect(sut.sourceTitle == "Input")
    }

    @Test
    mutating func sourceTitle_emptyStrip_isInput() {
        createSut()

        #expect(sut.sourceTitle == "Input")
    }

    // MARK: - slots

    @Test
    mutating func slots_emptyStrip_showsOnlySource() {
        createSut()

        #expect(sut.sourceSlot.id == 0)
        #expect(sut.insertSlots.isEmpty)
    }

    @Test
    mutating func insertSlots_filledStrip_addsOneTrailingEmptyInsert() {
        audioSettingsSpy.setup = .met
        purchasesSpy.state = .pro
        sessionSpy.slots = [.loading(component: Self.effect), .loading(component: Self.effect)]
        createSut()

        #expect(sut.insertSlots.map(\.id) == [1, 2])
        #expect(sut.insertSlots.last?.content == .empty(isEnabled: true))
    }

    // MARK: - content

    @Test
    mutating func content_emptySlot_isEnabledEmpty() {
        audioSettingsSpy.setup = .met
        createSut()

        #expect(sut.sourceSlot.content == .empty(isEnabled: true))
    }

    @Test
    mutating func content_loadingSlot_isLoading() {
        audioSettingsSpy.setup = .met
        sessionSpy.slots = [.loading(component: Self.effect)]
        createSut()

        #expect(sut.sourceSlot.content == .loading(component: Self.effect))
    }

    @Test
    mutating func content_selectedBypassedEffect_isLoadedBypassedAndSelected() {
        audioSettingsSpy.setup = .met
        sessionSpy.slots = [.loaded(audioUnit: LoadedAudioUnit(component: Self.effect), isBypassed: true)]
        createSut()

        #expect(sut.sourceSlot.content == .loaded(component: Self.effect, bypass: .bypassed, isSelected: true))
    }

    @Test
    mutating func content_unselectedActiveEffect_isLoadedActiveAndNotSelected() {
        audioSettingsSpy.setup = .met
        let loaded = PluginSlotContent.loaded(audioUnit: LoadedAudioUnit(component: Self.effect), isBypassed: false)
        sessionSpy.slots = [loaded, loaded]
        createSut()

        #expect(sut.insertSlots.first?.content == .loaded(component: Self.effect, bypass: .active, isSelected: false))
    }

    @Test
    mutating func content_instrument_hasNoBypass() {
        audioSettingsSpy.setup = .met
        sessionSpy.slots = [.loaded(audioUnit: LoadedAudioUnit(component: Self.instrument), isBypassed: false)]
        createSut()

        #expect(sut.sourceSlot.content == .loaded(component: Self.instrument, bypass: .unavailable, isSelected: true))
    }

    @Test
    mutating func content_failedSlot_isFailedWithSelection() {
        audioSettingsSpy.setup = .met
        sessionSpy.slots = [.failed(component: Self.effect, state: nil, isBypassed: false, message: "oops")]
        createSut()

        #expect(sut.sourceSlot.content == .failed(component: Self.effect, isSelected: true))
    }

    @Test
    mutating func content_setupUnmet_slotWithPlugin_isDisabled() {
        audioSettingsSpy.setup = .unmet([.microphonePermission])
        sessionSpy.slots = [.loaded(audioUnit: LoadedAudioUnit(component: Self.effect), isBypassed: false)]
        createSut()

        #expect(sut.sourceSlot.content == .disabled(component: Self.effect))
    }

    @Test
    mutating func content_setupUnmet_emptySlot_isDisabledEmpty() {
        audioSettingsSpy.setup = .unmet([.noOutputDevice])
        createSut()

        #expect(sut.sourceSlot.content == .empty(isEnabled: false))
    }

    @Test
    mutating func content_setupChecking_slotWithPlugin_isDisabled() {
        sessionSpy.slots = [.loading(component: Self.effect)]
        createSut()

        #expect(sut.sourceSlot.content == .disabled(component: Self.effect))
    }

    // MARK: - free tier

    @Test
    mutating func content_freeUserWithPlugin_emptySlotIsLocked() {
        audioSettingsSpy.setup = .met
        purchasesSpy.state = .free
        sessionSpy.slots = [.loaded(audioUnit: LoadedAudioUnit(component: Self.effect), isBypassed: false)]
        createSut()

        #expect(sut.insertSlots.last?.content == .locked)
    }

    @Test
    mutating func content_freeUserWithPlugin_gapIsLocked() {
        audioSettingsSpy.setup = .met
        purchasesSpy.state = .free
        sessionSpy.slots = [.empty, .loading(component: Self.effect)]
        createSut()

        #expect(sut.sourceSlot.content == .locked)
    }

    @Test
    mutating func content_freeUserWithoutPlugin_emptySlotIsAddable() {
        audioSettingsSpy.setup = .met
        purchasesSpy.state = .free
        createSut()

        #expect(sut.sourceSlot.content == .empty(isEnabled: true))
    }

    @Test
    mutating func content_purchasesStillLoading_emptySlotIsLocked() {
        audioSettingsSpy.setup = .met
        sessionSpy.slots = [.loading(component: Self.effect)]
        createSut()

        #expect(sut.insertSlots.last?.content == .locked)
    }

    @Test
    mutating func content_freeUserSetupUnmet_emptySlotIsDisabled() {
        audioSettingsSpy.setup = .unmet([.noOutputDevice])
        purchasesSpy.state = .free
        sessionSpy.slots = [.loading(component: Self.effect)]
        createSut()

        #expect(sut.insertSlots.last?.content == .empty(isEnabled: false))
    }

    @Test
    mutating func handleSlot_unlock_requestsProWindow() async {
        createSut()

        await sut.handleSlot(.unlock, at: 1)

        #expect(sut.isProWindowRequested)
        #expect(sessionSpy.calls.isEmpty)
    }

    @Test
    mutating func proWindowOpened_clearsRequest() async {
        createSut()
        await sut.handleSlot(.unlock, at: 1)

        sut.proWindowOpened()

        #expect(sut.isProWindowRequested == false)
    }

    // MARK: - catalogs

    @Test
    mutating func catalogs_sourceSlot_offersInstrumentsAndEffects() {
        librarySpy.components = [Self.instrument, Self.effect]
        createSut()

        #expect(sut.sourceSlot.catalogs == [
            .init(title: "Instruments", pluginGroups: [.init(manufacturer: "FakeCo", components: [Self.instrument])]),
            .init(title: "Effects", pluginGroups: [.init(manufacturer: "FakeCo", components: [Self.effect])]),
        ])
    }

    @Test
    mutating func catalogs_insertSlot_offersEffectsOnly() {
        librarySpy.components = [Self.instrument, Self.effect]
        sessionSpy.slots = [.loading(component: Self.effect)]
        createSut()

        #expect(sut.insertSlots.first?.catalogs == [
            .init(title: "Effects", pluginGroups: [.init(manufacturer: "FakeCo", components: [Self.effect])]),
        ])
    }

    @Test
    mutating func catalogs_groupsByManufacturerSortedCaseInsensitively() {
        let zebra = AudioUnitComponent.fake(name: "Z", manufacturer: "zebra")
        let apple = AudioUnitComponent.fake(name: "A", manufacturer: "Apple")
        librarySpy.components = [zebra, apple]
        sessionSpy.slots = [.loading(component: Self.effect)]
        createSut()

        #expect(sut.insertSlots.first?.catalogs.first?.pluginGroups.map(\.manufacturer) == ["Apple", "zebra"])
    }

    // MARK: - handleSlot

    @Test
    mutating func handleSlot_select_selectsSlot() async {
        createSut()

        await sut.handleSlot(.select, at: 2)

        #expect(sessionSpy.calls == [.select(2)])
    }

    @Test
    mutating func handleSlot_load_loadsComponentAtSlot() async {
        createSut()

        await sut.handleSlot(.load(Self.effect), at: 1)

        #expect(sessionSpy.calls == [.loadComponent(Self.effect, at: 1)])
    }

    @Test
    mutating func handleSlot_remove_unloadsSlot() async {
        createSut()

        await sut.handleSlot(.remove, at: 1)

        #expect(sessionSpy.calls == [.unload(at: 1)])
    }

    @Test
    mutating func handleSlot_toggleBypass_loadedSlot_flipsBypass() async {
        sessionSpy.slots = [.loaded(audioUnit: LoadedAudioUnit(component: Self.effect), isBypassed: true)]
        createSut()

        await sut.handleSlot(.toggleBypass, at: 0)

        #expect(sessionSpy.calls == [.setBypassed(false, at: 0)])
    }

    @Test
    mutating func handleSlot_toggleBypass_notLoadedSlot_doesNothing() async {
        sessionSpy.slots = [.loading(component: Self.effect)]
        createSut()

        await sut.handleSlot(.toggleBypass, at: 0)

        #expect(sessionSpy.calls.isEmpty)
    }
}

// MARK: - Test fixtures

private extension ChannelStripPresenterTests {
    static let effect = AudioUnitComponent.fake(id: .fakeEffect, name: "Effect")
    static let instrument = AudioUnitComponent.fake(id: .fakeInstrument, name: "Instrument")
}
