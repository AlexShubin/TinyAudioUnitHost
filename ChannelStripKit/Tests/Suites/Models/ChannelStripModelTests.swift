//
//  ChannelStripModelTests.swift
//  ChannelStripKitTests
//
//  Created by Alex Shubin on 21.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioUnitsKit
import AudioUnitsKitTestSupport
import Foundation
import ChannelStripKitTestSupport
import Testing
@testable import ChannelStripKit

@MainActor
@Suite
struct ChannelStripModelTests {
    var channelStripSpy: ChannelStripSpy!
    var sut: ChannelStripModelType!

    init() {
        channelStripSpy = ChannelStripSpy()
    }

    mutating func createSut() {
        sut = ChannelStripModel(channelStrip: channelStripSpy)
    }

    // MARK: - init

    @Test
    mutating func init_noSlotsAndNotBusy() {
        createSut()

        #expect(sut.slots == [])
        #expect(sut.isBusy == false)
        #expect(channelStripSpy.calls == [])
    }

    // MARK: - updateHardwareSettings

    @Test
    mutating func updateHardwareSettings_forwardsToChannelStrip() async {
        createSut()

        await sut.updateHardwareSettings(.fake(midi: .fake(sources: [10])))

        #expect(channelStripSpy.calls == [.updateHardwareSettings(.fake(midi: .fake(sources: [10])))])
    }

    // MARK: - load(component:at:)

    @Test
    mutating func load_whileLoading_slotLoadingAndBusy() async {
        let component = AudioUnitComponent.fake()
        channelStripSpy.loadResult = .success(LoadedAudioUnit(component: component))
        createSut()
        let model = sut!
        channelStripSpy.onLoad = {
            #expect(await model.slots == [.loading(component: component)])
            #expect(await model.isBusy)
        }

        await sut.load(component: component, at: 0)
    }

    @Test
    mutating func load_success_slotLoadedAndNotBusy() async {
        let component = AudioUnitComponent.fake()
        let loaded = LoadedAudioUnit(component: component)
        channelStripSpy.loadResult = .success(loaded)
        createSut()

        await sut.load(component: component, at: 0)

        #expect(sut.slots == [.loaded(audioUnit: loaded, isBypassed: false)])
        #expect(channelStripSpy.calls == [.load(slot: .fake(component: component), at: 0)])
        #expect(sut.isBusy == false)
    }

    @Test
    mutating func load_failure_slotFailedWithMessage() async {
        let component = AudioUnitComponent.fake()
        channelStripSpy.loadResult = .failure(.audioUnitInstantiationFailed)
        createSut()

        await sut.load(component: component, at: 0)

        #expect(sut.slots == [.failed(component: component, state: nil, isBypassed: false, message: "Couldn't load this audio unit.")])
    }

    @Test
    mutating func load_unloadedWhileLoading_dropsLoadResult() async {
        channelStripSpy.loadResult = .success(LoadedAudioUnit(component: .fake()))
        createSut()
        let model = sut!
        channelStripSpy.onLoad = {
            await model.unload(at: 0)
        }

        await sut.load(component: .fake(), at: 0)

        #expect(sut.slots == [])
    }

    @Test
    mutating func load_nextIndex_appendsAtThatChainPosition() async {
        let first = AudioUnitComponent.fake(name: "First")
        let second = AudioUnitComponent.fake(id: .init(type: 1, subType: 2, manufacturer: 3), name: "Second")
        channelStripSpy.loadResult = .success(LoadedAudioUnit(component: first))
        createSut()
        await sut.load(component: first, at: 0)

        await sut.load(component: second, at: 1)

        #expect(channelStripSpy.calls == [.load(slot: .fake(component: first), at: 0), .load(slot: .fake(component: second), at: 1)])
        #expect(sut.slots.count == 2)
    }

    @Test
    mutating func load_selectsTheSlot() async {
        channelStripSpy.loadResult = .success(LoadedAudioUnit(component: .fake()))
        createSut()
        await sut.load(component: .fake(), at: 0)

        await sut.load(component: .fake(), at: 1)

        #expect(sut.selectedIndex == 1)
    }

    // MARK: - unload

    @Test
    mutating func unload_unloadsFromChainAndRemovesLastSlot() async {
        let component = AudioUnitComponent.fake()
        channelStripSpy.loadResult = .success(LoadedAudioUnit(component: component))
        createSut()
        await sut.load(component: component, at: 0)

        await sut.unload(at: 0)

        #expect(channelStripSpy.calls == [.load(slot: .fake(component: component), at: 0), .unload(0)])
        #expect(sut.slots == [])
    }

    @Test
    mutating func unload_middleSlot_leavesGap() async {
        let loaded = LoadedAudioUnit(component: .fake())
        channelStripSpy.loadResult = .success(loaded)
        createSut()
        await sut.load(component: .fake(), at: 0)
        await sut.load(component: .fake(), at: 1)
        await sut.load(component: .fake(), at: 2)

        await sut.unload(at: 1)

        #expect(sut.slots == [
            .loaded(audioUnit: loaded, isBypassed: false),
            .empty,
            .loaded(audioUnit: loaded, isBypassed: false),
        ])
    }

    @Test
    mutating func unload_lastSlotAfterGap_trimsTrailingEmpties() async {
        let loaded = LoadedAudioUnit(component: .fake())
        channelStripSpy.loadResult = .success(loaded)
        createSut()
        await sut.load(component: .fake(), at: 0)
        await sut.load(component: .fake(), at: 1)
        await sut.load(component: .fake(), at: 2)
        await sut.unload(at: 1)

        await sut.unload(at: 2)

        #expect(sut.slots == [.loaded(audioUnit: loaded, isBypassed: false)])
    }

    @Test
    mutating func unload_selectedLastPlugin_selectsFirstPlugin() async {
        channelStripSpy.loadResult = .success(LoadedAudioUnit(component: .fake()))
        createSut()
        await sut.load(component: .fake(), at: 0)
        await sut.load(component: .fake(), at: 1)
        await sut.load(component: .fake(), at: 2)

        await sut.unload(at: 2)

        #expect(sut.selectedIndex == 0)
    }

    @Test
    mutating func unload_selectedFirstPlugin_selectsNextPlugin() async {
        channelStripSpy.loadResult = .success(LoadedAudioUnit(component: .fake()))
        createSut()
        await sut.load(component: .fake(), at: 0)
        await sut.load(component: .fake(), at: 1)
        sut.select(index: 0)

        await sut.unload(at: 0)

        #expect(sut.selectedIndex == 1)
    }

    @Test
    mutating func unload_unselectedPlugin_keepsSelection() async {
        channelStripSpy.loadResult = .success(LoadedAudioUnit(component: .fake()))
        createSut()
        await sut.load(component: .fake(), at: 0)
        await sut.load(component: .fake(), at: 1)
        await sut.load(component: .fake(), at: 2)

        await sut.unload(at: 1)

        #expect(sut.selectedIndex == 2)
    }

    @Test
    mutating func unload_onlyPlugin_keepsSelection() async {
        channelStripSpy.loadResult = .success(LoadedAudioUnit(component: .fake()))
        createSut()
        await sut.load(component: .fake(), at: 0)

        await sut.unload(at: 0)

        #expect(sut.selectedIndex == 0)
    }

    @Test
    mutating func unload_replacedWhileUnloading_showsReplacedSlots() async {
        let loaded = LoadedAudioUnit(component: .fake())
        channelStripSpy.loadResult = .success(LoadedAudioUnit(component: .fake()))
        channelStripSpy.loadSlotsResult = [.success(loaded)]
        createSut()
        await sut.load(component: .fake(), at: 0)
        await sut.load(component: .fake(), at: 1)
        await sut.load(component: .fake(), at: 2)
        let model = sut!
        channelStripSpy.onUnload = {
            await model.replace(with: [.fake()])
        }

        await sut.unload(at: 2)

        #expect(sut.slots == [.loaded(audioUnit: loaded, isBypassed: false)])
    }

    // MARK: - setBypassed

    @Test
    mutating func setBypassed_loaded_appliesToAudioUnitAndSlot() async {
        let loaded = LoadedAudioUnit(component: .fake())
        channelStripSpy.loadResult = .success(loaded)
        createSut()
        await sut.load(component: .fake(), at: 0)

        sut.setBypassed(true, at: 0)

        #expect(loaded.isBypassed)
        #expect(sut.slots == [.loaded(audioUnit: loaded, isBypassed: true)])
    }

    @Test
    mutating func setBypassed_noSlot_isNoOp() {
        createSut()

        sut.setBypassed(true, at: 0)

        #expect(sut.slots == [])
    }

    // MARK: - select

    @Test
    mutating func select_setsSelectedIndex() {
        createSut()

        sut.select(index: 2)

        #expect(sut.selectedIndex == 2)
    }

    // MARK: - replace

    @Test
    mutating func replace_loadsEverySlotAtOnce() async {
        let first = AudioUnitComponent.fake(name: "First")
        let third = AudioUnitComponent.fake(id: .init(type: 1, subType: 2, manufacturer: 3), name: "Third")
        let firstLoaded = LoadedAudioUnit(component: first)
        let thirdLoaded = LoadedAudioUnit(component: third)
        channelStripSpy.loadSlotsResult = [.success(firstLoaded), nil, .success(thirdLoaded)]
        createSut()

        await sut.replace(with: [
            .fake(component: first, state: Data([0x01])),
            nil,
            .fake(component: third, state: Data([0x03])),
        ])

        #expect(sut.slots == [
            .loaded(audioUnit: firstLoaded, isBypassed: false),
            .empty,
            .loaded(audioUnit: thirdLoaded, isBypassed: false),
        ])
        #expect(channelStripSpy.calls == [.load(slots: [
            .fake(component: first, state: Data([0x01])),
            nil,
            .fake(component: third, state: Data([0x03])),
        ])])
    }

    @Test
    mutating func replace_pluginFails_keepsItsStateInFailedSlot() async {
        let component = AudioUnitComponent.fake()
        channelStripSpy.loadSlotsResult = [.failure(.audioUnitInstantiationFailed)]
        createSut()

        await sut.replace(with: [.fake(component: component, state: Data([0x05]), isBypassed: true)])

        #expect(sut.slots == [
            .failed(component: component, state: Data([0x05]), isBypassed: true, message: "Couldn't load this audio unit."),
        ])
    }

    @Test
    mutating func replace_empty_clearsChain() async {
        channelStripSpy.loadResult = .success(LoadedAudioUnit(component: .fake()))
        createSut()
        await sut.load(component: .fake(), at: 0)

        await sut.replace(with: [])

        #expect(sut.slots == [])
        #expect(channelStripSpy.calls.last == .load(slots: []))
    }

    @Test
    mutating func replace_replacesEveryExistingSlot() async {
        let loaded = LoadedAudioUnit(component: .fake())
        channelStripSpy.loadResult = .success(LoadedAudioUnit(component: .fake()))
        channelStripSpy.loadSlotsResult = [.success(loaded)]
        createSut()
        await sut.load(component: .fake(), at: 0)
        await sut.load(component: .fake(), at: 1)
        await sut.load(component: .fake(), at: 2)

        await sut.replace(with: [.fake()])

        #expect(sut.slots == [.loaded(audioUnit: loaded, isBypassed: false)])
    }

    @Test
    mutating func replace_bypassedPlugin_loadsAndAppliesBypass() async {
        let component = AudioUnitComponent.fake()
        let loaded = LoadedAudioUnit(component: component)
        channelStripSpy.loadSlotsResult = [.success(loaded)]
        createSut()

        await sut.replace(with: [.fake(component: component, isBypassed: true)])

        #expect(loaded.isBypassed)
        #expect(sut.slots == [.loaded(audioUnit: loaded, isBypassed: true)])
    }

    @Test
    mutating func replace_notInstalledPlugin_failsSlotWithoutLoadingIt() async {
        let component = AudioUnitComponent.fake()
        channelStripSpy.loadSlotsResult = [nil]
        createSut()

        await sut.replace(with: [.fake(component: component, state: Data([0x02]), isInstalled: false)])

        #expect(sut.slots == [
            .failed(component: component, state: Data([0x02]), isBypassed: false, message: "This plug-in isn't installed."),
        ])
        #expect(channelStripSpy.calls == [.load(slots: [nil])])
    }

    @Test
    mutating func replace_selectionOnPlugin_keepsSelection() async {
        let loaded = LoadedAudioUnit(component: .fake())
        channelStripSpy.loadSlotsResult = [.success(loaded), .success(loaded), .success(loaded)]
        createSut()
        sut.select(index: 2)

        await sut.replace(with: [.fake(), .fake(), .fake()])

        #expect(sut.selectedIndex == 2)
    }

    @Test
    mutating func replace_selectionOnGap_selectsFirstPlugin() async {
        channelStripSpy.loadSlotsResult = [nil, .success(LoadedAudioUnit(component: .fake()))]
        createSut()

        await sut.replace(with: [nil, .fake()])

        #expect(sut.selectedIndex == 1)
    }

    @Test
    mutating func replace_shorterThanSelection_selectsFirstPlugin() async {
        channelStripSpy.loadSlotsResult = [.success(LoadedAudioUnit(component: .fake()))]
        createSut()
        sut.select(index: 2)

        await sut.replace(with: [.fake()])

        #expect(sut.selectedIndex == 0)
    }
}
