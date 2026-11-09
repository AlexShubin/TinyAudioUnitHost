//
//  PresetsModelTests.swift
//  PresetKitTests
//
//  Created by Alex Shubin on 09.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioUnitsKit
import AudioUnitsKitTestSupport
import Foundation
import PresetKitTestSupport
import StorageKit
import StorageKitTestSupport
import Testing
@testable import PresetKit

@Suite @MainActor
struct PresetsModelTests {
    var rawStoreSpy: RawPresetStoreSpy!
    var librarySpy: AudioUnitComponentsLibrarySpy!
    var delegateSpy: PresetsModelDelegateSpy!
    var sut: PresetsModelType!

    init() {
        rawStoreSpy = RawPresetStoreSpy()
        librarySpy = AudioUnitComponentsLibrarySpy()
        delegateSpy = PresetsModelDelegateSpy()
    }

    mutating func createSut() {
        sut = PresetsModel(
            rawStore: rawStoreSpy,
            library: librarySpy
        )
        sut.delegate = delegateSpy
    }

    // MARK: - init

    @Test
    mutating func init_emptyStore_exposesNoNamesAndNoActive() {
        createSut()

        #expect(sut.names == [])
        #expect(sut.activeName == nil)
    }

    @Test
    mutating func init_exposesStoredNamesAndActive() {
        rawStoreSpy.presets = ["b": .fake(), "a": .fake()]
        rawStoreSpy.currentActivePreset = RawActivePresetState(name: "b")
        createSut()

        #expect(sut.names == ["a", "b"])
        #expect(sut.activeName == "b")
    }

    @Test
    mutating func init_doesNotActivate() {
        rawStoreSpy.presets = ["a": .fake()]
        rawStoreSpy.currentActivePreset = RawActivePresetState(name: "a")
        createSut()

        #expect(delegateSpy.calls.isEmpty)
    }

    // MARK: - load

    @Test
    mutating func load_noActive_doesNotActivate() async {
        createSut()

        await sut.load()

        #expect(delegateSpy.calls.isEmpty)
    }

    @Test
    mutating func load_installedPlugin_activatesResolvedSlotWithStateAndBypass() async {
        let component = AudioUnitComponent.fake()
        rawStoreSpy.presets = ["MyPreset": .fake(pluginSlots: [component.rawSlot(state: Data([0x01]), isBypassed: true)])]
        rawStoreSpy.currentActivePreset = RawActivePresetState(name: "MyPreset")
        librarySpy.components = [component]
        createSut()

        await sut.load()

        #expect(delegateSpy.calls == [.presetsDidActivate(chain: [
            .fake(component: component, state: Data([0x01]), isBypassed: true, isInstalled: true),
        ])])
    }

    @Test
    mutating func load_installedPlugin_usesLibraryNameOverStoredName() async throws {
        rawStoreSpy.presets = ["MyPreset": .fake(pluginSlots: [AudioUnitComponent.fake(name: "Stale Name").rawSlot()])]
        rawStoreSpy.currentActivePreset = RawActivePresetState(name: "MyPreset")
        librarySpy.components = [.fake(name: "Live Name")]
        createSut()

        await sut.load()

        let slot = try #require(delegateSpy.activatedChain?.first ?? nil)
        #expect(slot.component.name == "Live Name")
    }

    @Test
    mutating func load_pluginNotInLibrary_activatesNotInstalledSlotWithStoredValues() async throws {
        rawStoreSpy.presets = [
            "Orphan": .fake(pluginSlots: [.fake(
                componentType: 99,
                componentSubType: 98,
                componentManufacturer: 97,
                name: "Gone",
                manufacturer: "Old Co",
                state: Data([0x02]),
                isBypassed: true
            )]),
        ]
        rawStoreSpy.currentActivePreset = RawActivePresetState(name: "Orphan")
        createSut()

        await sut.load()

        let slot = try #require(delegateSpy.activatedChain?.first ?? nil)
        #expect(slot == .fake(
            component: .fake(id: AudioUnitComponent.ID(type: 99, subType: 98, manufacturer: 97)),
            state: Data([0x02]),
            isBypassed: true,
            isInstalled: false
        ))
        #expect(slot.component.name == "Gone")
        #expect(slot.component.manufacturer == "Old Co")
    }

    @Test
    mutating func load_chain_keepsGapsAndResolvesEachSlot() async {
        let component = AudioUnitComponent.fake()
        rawStoreSpy.presets = [
            "Chain": .fake(pluginSlots: [nil, component.rawSlot(), .fake(componentType: 99, name: "Gone")]),
        ]
        rawStoreSpy.currentActivePreset = RawActivePresetState(name: "Chain")
        librarySpy.components = [component]
        createSut()

        await sut.load()

        #expect(delegateSpy.calls == [.presetsDidActivate(chain: [
            nil,
            .fake(component: component, isInstalled: true),
            .fake(component: .fake(id: AudioUnitComponent.ID(type: 99, subType: 0, manufacturer: 0)), isInstalled: false),
        ])])
    }

    @Test
    mutating func load_activeNotStored_activatesEmptyChainAndKeepsActive() async {
        rawStoreSpy.currentActivePreset = RawActivePresetState(name: "ghost")
        createSut()

        await sut.load()

        #expect(delegateSpy.calls == [.presetsDidActivate(chain: [])])
        #expect(sut.activeName == "ghost")
        #expect(rawStoreSpy.currentActivePreset == RawActivePresetState(name: "ghost"))
    }

    // MARK: - select

    @Test
    mutating func select_stored_savesActiveAndActivatesChain() async {
        let component = AudioUnitComponent.fake()
        rawStoreSpy.presets = ["foo": .fake(pluginSlots: [component.rawSlot()])]
        librarySpy.components = [component]
        createSut()

        await sut.select(name: "foo")

        #expect(sut.activeName == "foo")
        #expect(rawStoreSpy.currentActivePreset == RawActivePresetState(name: "foo"))
        #expect(delegateSpy.calls == [.presetsDidActivate(chain: [.fake(component: component)])])
    }

    @Test
    mutating func select_notStored_activatesEmptyChain() async {
        createSut()

        await sut.select(name: "missing")

        #expect(sut.activeName == "missing")
        #expect(delegateSpy.calls == [.presetsDidActivate(chain: [])])
    }

    // MARK: - saveCurrent

    @Test
    mutating func saveCurrent_noActive_isNoOp() {
        createSut()

        sut.saveCurrent(chain: [.fake()])

        #expect(rawStoreSpy.presets.isEmpty)
        #expect(sut.event == nil)
    }

    @Test
    mutating func saveCurrent_installedPlugin_writesComponentIdentityStateAndBypass() {
        let component = AudioUnitComponent.fake()
        rawStoreSpy.currentActivePreset = RawActivePresetState(name: "MyPreset")
        createSut()

        sut.saveCurrent(chain: [.fake(component: component, state: Data([0xBE, 0xEF]), isBypassed: true)])

        #expect(rawStoreSpy.presets["MyPreset"] == .fake(pluginSlots: [component.rawSlot(state: Data([0xBE, 0xEF]), isBypassed: true)]))
    }

    @Test
    mutating func saveCurrent_notInstalledPlugin_writesStoredValuesBack() {
        rawStoreSpy.currentActivePreset = RawActivePresetState(name: "Orphan")
        createSut()

        sut.saveCurrent(chain: [.fake(
            component: .fake(
                id: AudioUnitComponent.ID(type: 99, subType: 98, manufacturer: 97),
                name: "Gone",
                manufacturer: "Old Co"
            ),
            state: Data([0x02]),
            isBypassed: true,
            isInstalled: false
        )])

        #expect(rawStoreSpy.presets["Orphan"] == .fake(pluginSlots: [.fake(
            componentType: 99,
            componentSubType: 98,
            componentManufacturer: 97,
            name: "Gone",
            manufacturer: "Old Co",
            state: Data([0x02]),
            isBypassed: true
        )]))
    }

    @Test
    mutating func saveCurrent_chain_keepsGaps() {
        let component = AudioUnitComponent.fake()
        rawStoreSpy.currentActivePreset = RawActivePresetState(name: "Chain")
        createSut()

        sut.saveCurrent(chain: [nil, .fake(component: component)])

        #expect(rawStoreSpy.presets["Chain"] == .fake(pluginSlots: [nil, component.rawSlot()]))
    }

    @Test
    mutating func saveCurrent_pluginWithoutState_writesNilState() {
        let component = AudioUnitComponent.fake()
        rawStoreSpy.currentActivePreset = RawActivePresetState(name: "Fresh")
        createSut()

        sut.saveCurrent(chain: [.fake(component: component, state: nil)])

        #expect(rawStoreSpy.presets["Fresh"] == .fake(pluginSlots: [component.rawSlot(state: nil)]))
    }

    @Test
    mutating func saveCurrent_refreshesNamesAndReportsSaved() {
        rawStoreSpy.currentActivePreset = RawActivePresetState(name: "foo")
        createSut()

        sut.saveCurrent(chain: [.fake()])

        #expect(sut.names == ["foo"])
        #expect(sut.event?.kind == .saved)
    }

    @Test
    mutating func saveCurrent_thenRestore_notInstalledPluginRoundTrips() async throws {
        let slot = PresetSlot.fake(
            component: .fake(id: AudioUnitComponent.ID(type: 99, subType: 0, manufacturer: 0), name: "Gone"),
            state: Data([0x03]),
            isInstalled: false
        )
        rawStoreSpy.currentActivePreset = RawActivePresetState(name: "Orphan")
        createSut()

        sut.saveCurrent(chain: [slot])
        await sut.restoreActive()

        #expect(delegateSpy.calls == [.presetsDidActivate(chain: [slot])])
        let restored = try #require(delegateSpy.activatedChain?.first ?? nil)
        #expect(restored.component.name == "Gone")
    }

    // MARK: - restoreActive

    @Test
    mutating func restoreActive_noActive_isNoOp() async {
        createSut()

        await sut.restoreActive()

        #expect(delegateSpy.calls.isEmpty)
        #expect(sut.event == nil)
    }

    @Test
    mutating func restoreActive_activeNotStored_isNoOp() async {
        rawStoreSpy.currentActivePreset = RawActivePresetState(name: "ghost")
        createSut()

        await sut.restoreActive()

        #expect(delegateSpy.calls.isEmpty)
        #expect(sut.event == nil)
    }

    @Test
    mutating func restoreActive_activatesStoredChainAndReportsRestored() async {
        let component = AudioUnitComponent.fake()
        rawStoreSpy.presets = ["foo": .fake(pluginSlots: [component.rawSlot()])]
        rawStoreSpy.currentActivePreset = RawActivePresetState(name: "foo")
        librarySpy.components = [component]
        createSut()

        await sut.restoreActive()

        #expect(delegateSpy.calls == [.presetsDidActivate(chain: [.fake(component: component)])])
        #expect(sut.event?.kind == .restored)
    }

    // MARK: - saveAsNew

    @Test
    mutating func saveAsNew_savesSetsActiveAndReportsSaved() {
        let component = AudioUnitComponent.fake()
        rawStoreSpy.presets = ["old": .fake()]
        rawStoreSpy.currentActivePreset = RawActivePresetState(name: "old")
        createSut()

        sut.saveAsNew(name: "new", chain: [.fake(component: component)])

        #expect(rawStoreSpy.presets["new"] == .fake(pluginSlots: [component.rawSlot()]))
        #expect(rawStoreSpy.currentActivePreset == RawActivePresetState(name: "new"))
        #expect(sut.activeName == "new")
        #expect(sut.names == ["new", "old"])
        #expect(sut.event?.kind == .saved)
    }

    // MARK: - acknowledgeEvent

    @Test
    mutating func acknowledgeEvent_clearsEvent() {
        rawStoreSpy.currentActivePreset = RawActivePresetState(name: "foo")
        createSut()
        sut.saveCurrent(chain: [.fake()])

        sut.acknowledgeEvent()

        #expect(sut.event == nil)
    }

    // MARK: - rename

    @Test
    mutating func rename_movesStoredPresetAndRefreshesNames() {
        let preset = RawPreset.fake(pluginSlots: [.fake(componentType: 5)])
        rawStoreSpy.presets = ["old": preset]
        createSut()

        sut.rename(from: "old", to: "new")

        #expect(rawStoreSpy.presets == ["new": preset])
        #expect(sut.names == ["new"])
    }

    @Test
    mutating func rename_activeMatchesOld_followsToNew() {
        rawStoreSpy.presets = ["old": .fake()]
        rawStoreSpy.currentActivePreset = RawActivePresetState(name: "old")
        createSut()

        sut.rename(from: "old", to: "new")

        #expect(rawStoreSpy.currentActivePreset == RawActivePresetState(name: "new"))
        #expect(sut.activeName == "new")
    }

    @Test
    mutating func rename_activeDoesNotMatch_leavesActiveUnchanged() {
        rawStoreSpy.presets = ["old": .fake()]
        rawStoreSpy.currentActivePreset = RawActivePresetState(name: "keeper")
        createSut()

        sut.rename(from: "old", to: "new")

        #expect(rawStoreSpy.currentActivePreset == RawActivePresetState(name: "keeper"))
        #expect(sut.activeName == "keeper")
    }

    // MARK: - delete

    @Test
    mutating func delete_removesStoredPresetAndRefreshesNames() {
        rawStoreSpy.presets = ["target": .fake(), "other": .fake()]
        createSut()

        sut.delete(name: "target")

        #expect(rawStoreSpy.presets["target"] == nil)
        #expect(sut.names == ["other"])
    }

    @Test
    mutating func delete_activeMatches_clearsActive() {
        rawStoreSpy.presets = ["target": .fake()]
        rawStoreSpy.currentActivePreset = RawActivePresetState(name: "target")
        createSut()

        sut.delete(name: "target")

        #expect(rawStoreSpy.currentActivePreset == nil)
        #expect(sut.activeName == nil)
    }

    @Test
    mutating func delete_activeDoesNotMatch_leavesActiveUnchanged() {
        rawStoreSpy.presets = ["target": .fake()]
        rawStoreSpy.currentActivePreset = RawActivePresetState(name: "keeper")
        createSut()

        sut.delete(name: "target")

        #expect(rawStoreSpy.currentActivePreset == RawActivePresetState(name: "keeper"))
        #expect(sut.activeName == "keeper")
    }
}

private extension AudioUnitComponent {
    func rawSlot(state: Data? = Data(), isBypassed: Bool = false) -> RawPreset.PluginSlot {
        .fake(
            componentType: id.type,
            componentSubType: id.subType,
            componentManufacturer: id.manufacturer,
            name: name,
            manufacturer: manufacturer,
            state: state,
            isBypassed: isBypassed
        )
    }
}

private extension PresetsModelDelegateSpy {
    var activatedChain: [PresetSlot?]? {
        guard case .presetsDidActivate(let chain) = calls.last else { return nil }
        return chain
    }
}
