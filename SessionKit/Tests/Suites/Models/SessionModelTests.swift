//
//  SessionModelTests.swift
//  SessionKitTests
//
//  Created by Alex Shubin on 21.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioUnitsKit
import AudioUnitsKitTestSupport
import Foundation
import PresetKit
import PresetKitTestSupport
import Testing
@testable import SessionKit

@MainActor
@Suite
struct SessionModelTests {
    var channelStripSpy: ChannelStripSpy!
    var presetProviderSpy: PresetProviderSpy!
    var sut: SessionModelType!

    init() {
        channelStripSpy = ChannelStripSpy()
        presetProviderSpy = PresetProviderSpy()
    }

    mutating func createSut() {
        sut = SessionModel(
            channelStrip: channelStripSpy,
            presetProvider: presetProviderSpy
        )
    }

    // MARK: - init

    @Test
    mutating func init_exposesStoredPresets() {
        presetProviderSpy = PresetProviderSpy(presets: [
            "a": Preset.fake(name: "a"),
            "b": Preset.fake(name: "b"),
            "c": Preset.fake(name: "c"),
        ])
        createSut()

        #expect(sut.presets.sorted() == ["a", "b", "c"])
    }

    @Test
    mutating func init_noActivePreset_noSlotsAndNotBusy() {
        createSut()

        #expect(sut.slots == [])
        #expect(sut.activePresetName == nil)
        #expect(sut.isBusy == false)
    }

    @Test
    mutating func init_activePreset_exposesNameWithoutLoading() {
        presetProviderSpy = PresetProviderSpy(
            presets: ["foo": Preset.fake(name: "foo")],
            activeName: "foo"
        )
        createSut()

        #expect(sut.activePresetName == "foo")
        #expect(sut.slots == [])
        #expect(channelStripSpy.calls == [])
    }

    // MARK: - load

    @Test
    mutating func load_activePreset_loadsEveryPluginSlotAtOnce() async {
        let first = AudioUnitComponent.fake(name: "First")
        let third = AudioUnitComponent.fake(id: .init(type: 1, subType: 2, manufacturer: 3), name: "Third")
        let firstLoaded = LoadedAudioUnit(component: first)
        let thirdLoaded = LoadedAudioUnit(component: third)
        presetProviderSpy = PresetProviderSpy(
            presets: ["foo": Preset.fake(name: "foo", pluginSlots: [
                .fake(component: first, state: Data([0x01])),
                nil,
                .fake(component: third, state: Data([0x03])),
            ])],
            activeName: "foo"
        )
        channelStripSpy.loadSlotsResult = [.success(firstLoaded), nil, .success(thirdLoaded)]
        createSut()

        await sut.load()

        #expect(sut.slots == [
            .loaded(audioUnit: firstLoaded, isBypassed: false),
            .empty,
            .loaded(audioUnit: thirdLoaded, isBypassed: false),
        ])
        #expect(channelStripSpy.calls == [.load([
            .fake(component: first, state: Data([0x01])),
            nil,
            .fake(component: third, state: Data([0x03])),
        ])])
    }

    @Test
    mutating func load_presetPluginFails_keepsItsStateInFailedSlot() async {
        let component = AudioUnitComponent.fake()
        presetProviderSpy = PresetProviderSpy(
            presets: ["foo": Preset.fake(name: "foo", pluginSlots: [.fake(component: component, state: Data([0x05]), isBypassed: true)])],
            activeName: "foo"
        )
        channelStripSpy.loadSlotsResult = [.failure(.audioUnitInstantiationFailed)]
        createSut()

        await sut.load()

        #expect(sut.slots == [
            .failed(component: component, state: Data([0x05]), isBypassed: true, message: "Couldn't load this audio unit."),
        ])
    }

    @Test
    mutating func load_noActivePreset_leavesSlotsEmpty() async {
        createSut()

        await sut.load()

        #expect(sut.slots == [])
        #expect(channelStripSpy.calls == [])
    }

    @Test
    mutating func load_storedActiveStale_keepsActiveAndClearsChain() async {
        presetProviderSpy = PresetProviderSpy(activeName: "ghost")
        createSut()

        await sut.load()

        #expect(sut.slots == [])
        #expect(channelStripSpy.calls == [.load([])])
        #expect(sut.activePresetName == "ghost")
        #expect(!presetProviderSpy.calls.contains(.setActive(nil)))
    }

    // MARK: - load(_:at:)

    @Test
    mutating func load_whileLoading_slotLoadingAndBusy() async {
        let component = AudioUnitComponent.fake()
        channelStripSpy.loadResult = .success(LoadedAudioUnit(component: component))
        createSut()
        let session = sut!
        channelStripSpy.onLoad = {
            #expect(await session.slots == [.loading(component: component)])
            #expect(await session.isBusy)
        }

        await sut.load(component, at: 0)
    }

    @Test
    mutating func load_success_slotLoadedAndNotBusy() async {
        let component = AudioUnitComponent.fake()
        let loaded = LoadedAudioUnit(component: component)
        channelStripSpy.loadResult = .success(loaded)
        createSut()

        await sut.load(component, at: 0)

        #expect(sut.slots == [.loaded(audioUnit: loaded, isBypassed: false)])
        #expect(channelStripSpy.calls == [.load(.fake(component: component), at: 0)])
        #expect(sut.isBusy == false)
    }

    @Test
    mutating func load_failure_slotFailedWithMessage() async {
        let component = AudioUnitComponent.fake()
        channelStripSpy.loadResult = .failure(.audioUnitInstantiationFailed)
        createSut()

        await sut.load(component, at: 0)

        #expect(sut.slots == [.failed(component: component, state: nil, isBypassed: false, message: "Couldn't load this audio unit.")])
    }

    @Test
    mutating func load_unloadedWhileLoading_dropsLoadResult() async {
        channelStripSpy.loadResult = .success(LoadedAudioUnit(component: .fake()))
        createSut()
        let session = sut!
        channelStripSpy.onLoad = {
            await session.unload(at: 0)
        }

        await sut.load(.fake(), at: 0)

        #expect(sut.slots == [])
    }

    @Test
    mutating func load_nextIndex_appendsAtThatChainPosition() async {
        let first = AudioUnitComponent.fake(name: "First")
        let second = AudioUnitComponent.fake(id: .init(type: 1, subType: 2, manufacturer: 3), name: "Second")
        channelStripSpy.loadResult = .success(LoadedAudioUnit(component: first))
        createSut()
        await sut.load(first, at: 0)

        await sut.load(second, at: 1)

        #expect(channelStripSpy.calls == [.load(.fake(component: first), at: 0), .load(.fake(component: second), at: 1)])
        #expect(sut.slots.count == 2)
    }

    @Test
    mutating func load_selectsTheSlot() async {
        channelStripSpy.loadResult = .success(LoadedAudioUnit(component: .fake()))
        createSut()
        await sut.load(.fake(), at: 0)

        await sut.load(.fake(), at: 1)

        #expect(sut.selectedIndex == 1)
    }

    // MARK: - unload

    @Test
    mutating func unload_unloadsFromChainAndRemovesLastSlot() async {
        let component = AudioUnitComponent.fake()
        channelStripSpy.loadResult = .success(LoadedAudioUnit(component: component))
        createSut()
        await sut.load(component, at: 0)

        await sut.unload(at: 0)

        #expect(channelStripSpy.calls == [.load(.fake(component: component), at: 0), .unload(0)])
        #expect(sut.slots == [])
    }

    @Test
    mutating func unload_middleSlot_leavesGap() async {
        let loaded = LoadedAudioUnit(component: .fake())
        channelStripSpy.loadResult = .success(loaded)
        createSut()
        await sut.load(.fake(), at: 0)
        await sut.load(.fake(), at: 1)
        await sut.load(.fake(), at: 2)

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
        await sut.load(.fake(), at: 0)
        await sut.load(.fake(), at: 1)
        await sut.load(.fake(), at: 2)
        await sut.unload(at: 1)

        await sut.unload(at: 2)

        #expect(sut.slots == [.loaded(audioUnit: loaded, isBypassed: false)])
    }

    @Test
    mutating func unload_selectedLastPlugin_selectsFirstPlugin() async {
        channelStripSpy.loadResult = .success(LoadedAudioUnit(component: .fake()))
        createSut()
        await sut.load(.fake(), at: 0)
        await sut.load(.fake(), at: 1)
        await sut.load(.fake(), at: 2)

        await sut.unload(at: 2)

        #expect(sut.selectedIndex == 0)
    }

    @Test
    mutating func unload_selectedFirstPlugin_selectsNextPlugin() async {
        channelStripSpy.loadResult = .success(LoadedAudioUnit(component: .fake()))
        createSut()
        await sut.load(.fake(), at: 0)
        await sut.load(.fake(), at: 1)
        sut.select(0)

        await sut.unload(at: 0)

        #expect(sut.selectedIndex == 1)
    }

    @Test
    mutating func unload_unselectedPlugin_keepsSelection() async {
        channelStripSpy.loadResult = .success(LoadedAudioUnit(component: .fake()))
        createSut()
        await sut.load(.fake(), at: 0)
        await sut.load(.fake(), at: 1)
        await sut.load(.fake(), at: 2)

        await sut.unload(at: 1)

        #expect(sut.selectedIndex == 2)
    }

    @Test
    mutating func unload_onlyPlugin_keepsSelection() async {
        channelStripSpy.loadResult = .success(LoadedAudioUnit(component: .fake()))
        createSut()
        await sut.load(.fake(), at: 0)

        await sut.unload(at: 0)

        #expect(sut.selectedIndex == 0)
    }

    @Test
    mutating func unload_keepsActivePreset() async {
        let component = AudioUnitComponent.fake()
        presetProviderSpy = PresetProviderSpy(
            presets: ["foo": Preset.fake(name: "foo", pluginSlots: [.fake(component: component)])],
            activeName: "foo"
        )
        channelStripSpy.loadSlotsResult = [.success(LoadedAudioUnit(component: component))]
        createSut()
        await sut.load()

        await sut.unload(at: 0)

        #expect(sut.activePresetName == "foo")
        #expect(!presetProviderSpy.calls.contains(.setActive(nil)))
    }

    @Test
    mutating func unload_presetSelectedWhileUnloading_showsPresetSlots() async {
        let loaded = LoadedAudioUnit(component: .fake())
        presetProviderSpy = PresetProviderSpy(presets: ["foo": Preset.fake(name: "foo")])
        channelStripSpy.loadResult = .success(LoadedAudioUnit(component: .fake()))
        channelStripSpy.loadSlotsResult = [.success(loaded)]
        createSut()
        await sut.load(.fake(), at: 0)
        await sut.load(.fake(), at: 1)
        await sut.load(.fake(), at: 2)
        let session = sut!
        channelStripSpy.onUnload = {
            await session.selectPreset(name: "foo")
        }

        await sut.unload(at: 2)

        #expect(sut.slots == [.loaded(audioUnit: loaded, isBypassed: false)])
    }

    @Test
    mutating func unload_presetRestoredWhileUnloading_showsRestoredSlots() async {
        let first = LoadedAudioUnit(component: .fake())
        let second = LoadedAudioUnit(component: .fake())
        presetProviderSpy = PresetProviderSpy(
            presets: ["foo": Preset.fake(name: "foo", pluginSlots: [.fake(), .fake()])],
            activeName: "foo"
        )
        channelStripSpy.loadSlotsResult = [.success(first), .success(second)]
        createSut()
        await sut.load()
        let session = sut!
        channelStripSpy.onUnload = {
            await session.restoreActivePreset()
        }

        await sut.unload(at: 1)

        #expect(sut.slots == [.loaded(audioUnit: first, isBypassed: false), .loaded(audioUnit: second, isBypassed: false)])
    }

    // MARK: - setBypassed

    @Test
    mutating func setBypassed_loaded_appliesToAudioUnitAndSlot() async {
        let loaded = LoadedAudioUnit(component: .fake())
        channelStripSpy.loadResult = .success(loaded)
        createSut()
        await sut.load(.fake(), at: 0)

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

        sut.select(2)

        #expect(sut.selectedIndex == 2)
    }

    // MARK: - canSavePreset

    @Test
    mutating func canSavePreset_slotLoaded_isTrue() async {
        channelStripSpy.loadResult = .success(LoadedAudioUnit(component: .fake()))
        createSut()

        await sut.load(.fake(), at: 0)

        #expect(sut.canSavePreset)
    }

    @Test
    mutating func canSavePreset_onlyLaterSlotLoaded_isTrue() async {
        channelStripSpy.loadResult = .success(LoadedAudioUnit(component: .fake()))
        createSut()
        await sut.load(.fake(), at: 0)
        await sut.load(.fake(), at: 1)

        await sut.unload(at: 0)

        #expect(sut.canSavePreset)
    }

    @Test
    mutating func canSavePreset_onlyFailedSlots_isFalse() async {
        createSut()

        await sut.load(.fake(), at: 0)

        #expect(sut.canSavePreset == false)
    }

    @Test
    mutating func canSavePreset_slotLoading_isFalse() async {
        channelStripSpy.loadResult = .success(LoadedAudioUnit(component: .fake()))
        createSut()
        await sut.load(.fake(), at: 0)
        let session = sut!
        channelStripSpy.onLoad = {
            #expect(await session.canSavePreset == false)
        }

        await sut.load(.fake(), at: 1)
    }

    // MARK: - selectPreset

    @Test
    mutating func selectPreset_existing_setsActiveAndLoads() async {
        let component = AudioUnitComponent.fake()
        let loaded = LoadedAudioUnit(component: component)
        presetProviderSpy = PresetProviderSpy(
            presets: ["foo": Preset.fake(name: "foo", pluginSlots: [.fake(component: component, state: Data([0x07]))])]
        )
        channelStripSpy.loadSlotsResult = [.success(loaded)]
        createSut()

        await sut.selectPreset(name: "foo")

        #expect(sut.activePresetName == "foo")
        #expect(sut.slots == [.loaded(audioUnit: loaded, isBypassed: false)])
        #expect(presetProviderSpy.calls.contains(.setActive("foo")))
        #expect(channelStripSpy.calls == [.load([.fake(component: component, state: Data([0x07]))])])
    }

    @Test
    mutating func selectPreset_replacesEveryExistingSlot() async {
        let loaded = LoadedAudioUnit(component: .fake())
        presetProviderSpy = PresetProviderSpy(presets: ["foo": Preset.fake(name: "foo")])
        channelStripSpy.loadResult = .success(LoadedAudioUnit(component: .fake()))
        channelStripSpy.loadSlotsResult = [.success(loaded)]
        createSut()
        await sut.load(.fake(), at: 0)
        await sut.load(.fake(), at: 1)
        await sut.load(.fake(), at: 2)

        await sut.selectPreset(name: "foo")

        #expect(sut.slots == [.loaded(audioUnit: loaded, isBypassed: false)])
    }

    @Test
    mutating func selectPreset_missing_clearsChain() async {
        createSut()

        await sut.selectPreset(name: "ghost")

        #expect(sut.activePresetName == "ghost")
        #expect(sut.slots == [])
        #expect(channelStripSpy.calls == [.load([])])
    }

    @Test
    mutating func selectPreset_bypassedPlugin_loadsAndAppliesBypass() async {
        let component = AudioUnitComponent.fake()
        let loaded = LoadedAudioUnit(component: component)
        presetProviderSpy = PresetProviderSpy(
            presets: ["foo": Preset.fake(name: "foo", pluginSlots: [.fake(component: component, isBypassed: true)])]
        )
        channelStripSpy.loadSlotsResult = [.success(loaded)]
        createSut()

        await sut.selectPreset(name: "foo")

        #expect(loaded.isBypassed)
        #expect(sut.slots == [.loaded(audioUnit: loaded, isBypassed: true)])
    }

    @Test
    mutating func selectPreset_notInstalledPlugin_failsSlotWithoutLoadingIt() async {
        let component = AudioUnitComponent.fake()
        presetProviderSpy = PresetProviderSpy(
            presets: ["foo": Preset.fake(name: "foo", pluginSlots: [.fake(component: component, state: Data([0x02]), isInstalled: false)])]
        )
        channelStripSpy.loadSlotsResult = [nil]
        createSut()

        await sut.selectPreset(name: "foo")

        #expect(sut.slots == [
            .failed(component: component, state: Data([0x02]), isBypassed: false, message: "This plug-in isn't installed."),
        ])
        #expect(channelStripSpy.calls == [.load([nil])])
    }

    @Test
    mutating func selectPreset_noPluginSlots_clearsChain() async {
        presetProviderSpy = PresetProviderSpy(presets: ["foo": Preset.fake(name: "foo", pluginSlots: [])])
        createSut()

        await sut.selectPreset(name: "foo")

        #expect(sut.slots == [])
        #expect(channelStripSpy.calls == [.load([])])
    }

    @Test
    mutating func selectPreset_selectionOnPlugin_keepsSelection() async {
        let loaded = LoadedAudioUnit(component: .fake())
        presetProviderSpy = PresetProviderSpy(presets: ["foo": Preset.fake(name: "foo", pluginSlots: [.fake(), .fake(), .fake()])])
        channelStripSpy.loadSlotsResult = [.success(loaded), .success(loaded), .success(loaded)]
        createSut()
        sut.select(2)

        await sut.selectPreset(name: "foo")

        #expect(sut.selectedIndex == 2)
    }

    @Test
    mutating func selectPreset_selectionOnGap_selectsFirstPlugin() async {
        presetProviderSpy = PresetProviderSpy(presets: ["foo": Preset.fake(name: "foo", pluginSlots: [nil, .fake()])])
        channelStripSpy.loadSlotsResult = [nil, .success(LoadedAudioUnit(component: .fake()))]
        createSut()

        await sut.selectPreset(name: "foo")

        #expect(sut.selectedIndex == 1)
    }

    @Test
    mutating func selectPreset_shorterThanSelection_selectsFirstPlugin() async {
        presetProviderSpy = PresetProviderSpy(presets: ["foo": Preset.fake(name: "foo")])
        channelStripSpy.loadSlotsResult = [.success(LoadedAudioUnit(component: .fake()))]
        createSut()
        sut.select(2)

        await sut.selectPreset(name: "foo")

        #expect(sut.selectedIndex == 0)
    }

    // MARK: - saveCurrentPreset

    @Test
    mutating func saveCurrentPreset_notLoaded_isNoOp() {
        createSut()

        sut.saveCurrentPreset()

        #expect(!presetProviderSpy.calls.contains { if case .save = $0 { return true } else { return false } })
        #expect(sut.presetEvent == nil)
    }

    @Test
    mutating func saveCurrentPreset_happyPath_savesAndNotifies() async {
        let component = AudioUnitComponent.fake()
        let loaded = LoadedAudioUnit(component: component, fullState: Data([0xBE, 0xEF]))
        presetProviderSpy = PresetProviderSpy(
            presets: ["foo": Preset.fake(name: "foo", pluginSlots: [.fake(component: component)])],
            activeName: "foo"
        )
        channelStripSpy.loadSlotsResult = [.success(loaded)]
        createSut()
        await sut.load()

        sut.saveCurrentPreset()

        let saved = Preset.fake(name: "foo", pluginSlots: [.fake(component: component, state: Data([0xBE, 0xEF]))])
        #expect(presetProviderSpy.calls.contains(.save(saved)))
        #expect(sut.presetEvent?.kind == .saved)
    }

    @Test
    mutating func saveCurrentPreset_wholeChain_savesGapsAndFailedPluginsWithTheirState() async {
        let first = AudioUnitComponent.fake(name: "First")
        let missing = AudioUnitComponent.fake(id: .init(type: 1, subType: 2, manufacturer: 3), name: "Missing")
        presetProviderSpy = PresetProviderSpy(
            presets: ["foo": Preset.fake(name: "foo", pluginSlots: [
                .fake(component: first),
                nil,
                .fake(component: missing, state: Data([0x02]), isBypassed: true, isInstalled: false),
            ])],
            activeName: "foo"
        )
        channelStripSpy.loadSlotsResult = [.success(LoadedAudioUnit(component: first, fullState: Data([0xAA]))), nil, nil]
        createSut()
        await sut.load()

        sut.saveCurrentPreset()

        let saved = Preset.fake(name: "foo", pluginSlots: [
            .fake(component: first, state: Data([0xAA])),
            nil,
            .fake(component: missing, state: Data([0x02]), isBypassed: true),
        ])
        #expect(presetProviderSpy.calls.contains(.save(saved)))
    }

    @Test
    mutating func saveCurrentPreset_failedPick_savesComponentWithoutState() async {
        let failed = AudioUnitComponent.fake(name: "Failed")
        let loaded = AudioUnitComponent.fake(id: .init(type: 1, subType: 2, manufacturer: 3), name: "Loaded")
        presetProviderSpy = PresetProviderSpy(presets: ["foo": Preset.fake(name: "foo")], activeName: "foo")
        createSut()
        await sut.load(failed, at: 0)
        channelStripSpy.loadResult = .success(LoadedAudioUnit(component: loaded, fullState: Data([0x01])))
        await sut.load(loaded, at: 1)

        sut.saveCurrentPreset()

        let saved = Preset.fake(name: "foo", pluginSlots: [
            .fake(component: failed, state: nil),
            .fake(component: loaded, state: Data([0x01])),
        ])
        #expect(presetProviderSpy.calls.contains(.save(saved)))
    }

    @Test
    mutating func saveCurrentPreset_bypassedPlugin_savesBypass() async {
        let component = AudioUnitComponent.fake()
        let loaded = LoadedAudioUnit(component: component, fullState: Data([0x01]))
        presetProviderSpy = PresetProviderSpy(
            presets: ["foo": Preset.fake(name: "foo", pluginSlots: [.fake(component: component)])],
            activeName: "foo"
        )
        channelStripSpy.loadSlotsResult = [.success(loaded)]
        createSut()
        await sut.load()
        sut.setBypassed(true, at: 0)

        sut.saveCurrentPreset()

        let saved = Preset.fake(name: "foo", pluginSlots: [.fake(component: component, state: Data([0x01]), isBypassed: true)])
        #expect(presetProviderSpy.calls.contains(.save(saved)))
    }

    // MARK: - restoreActivePreset

    @Test
    mutating func restoreActivePreset_noActive_isNoOp() async {
        createSut()

        await sut.restoreActivePreset()

        #expect(channelStripSpy.calls == [])
        #expect(sut.presetEvent == nil)
    }

    @Test
    mutating func restoreActivePreset_happyPath_notifies() async {
        let component = AudioUnitComponent.fake()
        let loaded = LoadedAudioUnit(component: component)
        presetProviderSpy = PresetProviderSpy(
            presets: ["foo": Preset.fake(name: "foo", pluginSlots: [.fake(component: component, state: Data([0x09]))])],
            activeName: "foo"
        )
        channelStripSpy.loadSlotsResult = [.success(loaded)]
        createSut()
        await sut.load()

        await sut.restoreActivePreset()

        #expect(sut.slots == [.loaded(audioUnit: loaded, isBypassed: false)])
        #expect(sut.presetEvent?.kind == .restored)
    }

    @Test
    mutating func restoreActivePreset_pluginFails_doesNotNotify() async {
        presetProviderSpy = PresetProviderSpy(presets: ["foo": Preset.fake(name: "foo")], activeName: "foo")
        channelStripSpy.loadSlotsResult = [.failure(.audioUnitInstantiationFailed)]
        createSut()

        await sut.restoreActivePreset()

        #expect(sut.presetEvent == nil)
    }

    // MARK: - saveAsNewPreset

    @Test
    mutating func saveAsNewPreset_notLoaded_isNoOp() {
        createSut()

        sut.saveAsNewPreset(name: "anything")

        #expect(presetProviderSpy.storedPresets.isEmpty)
        #expect(sut.presetEvent == nil)
    }

    @Test
    mutating func saveAsNewPreset_happyPath_savesSetsActiveAndNotifies() async {
        let component = AudioUnitComponent.fake()
        channelStripSpy.loadResult = .success(LoadedAudioUnit(component: component, fullState: Data([0xAA])))
        createSut()
        await sut.load(component, at: 0)

        sut.saveAsNewPreset(name: "MyNew")

        #expect(sut.activePresetName == "MyNew")
        #expect(presetProviderSpy.currentActiveName == "MyNew")
        #expect(sut.presetEvent?.kind == .saved)
    }

    // MARK: - acknowledgePresetEvent

    @Test
    mutating func acknowledgePresetEvent_clearsEvent() async {
        let component = AudioUnitComponent.fake()
        channelStripSpy.loadResult = .success(LoadedAudioUnit(component: component, fullState: Data([0x01])))
        createSut()
        await sut.load(component, at: 0)
        sut.saveAsNewPreset(name: "foo")
        #expect(sut.presetEvent?.kind == .saved)

        sut.acknowledgePresetEvent()

        #expect(sut.presetEvent == nil)
    }

    // MARK: - renamePreset

    @Test
    mutating func renamePreset_forwardsToProviderAndRefreshes() {
        presetProviderSpy = PresetProviderSpy(
            presets: ["old": Preset.fake(name: "old")],
            activeName: "old"
        )
        createSut()

        sut.renamePreset(from: "old", to: "new")

        #expect(presetProviderSpy.calls.contains(.rename(from: "old", to: "new")))
        #expect(sut.activePresetName == "new")
    }

    // MARK: - deletePreset

    @Test
    mutating func deletePreset_forwardsAndClearsActiveIfMatched() {
        presetProviderSpy = PresetProviderSpy(
            presets: ["target": Preset.fake(name: "target")],
            activeName: "target"
        )
        createSut()

        sut.deletePreset(name: "target")

        #expect(presetProviderSpy.calls.contains(.delete(name: "target")))
        #expect(sut.activePresetName == nil)
    }
}
