//
//  PresetProviderTests.swift
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

@Suite
struct PresetProviderTests {
    var rawStoreSpy: RawPresetStoreSpy!
    var librarySpy: AudioUnitComponentsLibrarySpy!
    var sut: PresetProviderType!

    init() {
        rawStoreSpy = RawPresetStoreSpy()
        librarySpy = AudioUnitComponentsLibrarySpy()
    }

    mutating func createSut() {
        sut = PresetProvider(
            rawStore: rawStoreSpy,
            library: librarySpy
        )
    }

    // MARK: - presets

    @Test
    mutating func presets_emptyStore_returnsEmpty() {
        createSut()

        #expect(sut.presets == [])
    }

    @Test
    mutating func presets_returnsStoredNames() {
        let component = AudioUnitComponent.fake()
        rawStoreSpy.presets = [
            "MyPreset": .fake(pluginSlots: [component.rawSlot(state: Data([0x01]))]),
        ]
        librarySpy.components = [component]
        createSut()

        #expect(sut.presets == ["MyPreset"])
    }

    @Test
    mutating func presets_componentNotInLibrary_stillListsName() {
        let component = AudioUnitComponent.fake()
        rawStoreSpy.presets = [
            "Resolved": .fake(pluginSlots: [component.rawSlot()]),
            "Orphan": .fake(pluginSlots: [.fake(componentType: 99, componentSubType: 99, componentManufacturer: 99)]),
        ]
        librarySpy.components = [component]
        createSut()

        #expect(sut.presets.sorted() == ["Orphan", "Resolved"])
    }

    // MARK: - activeName

    @Test
    mutating func activeName_noActive_returnsNil() {
        createSut()

        #expect(sut.activeName == nil)
    }

    @Test
    mutating func activeName_present_returnsName() {
        rawStoreSpy.currentActivePreset = RawActivePresetState(name: "MyPreset")
        createSut()

        #expect(sut.activeName == "MyPreset")
    }

    // MARK: - setActive

    @Test
    mutating func setActive_name_savesActivePresetOnRawStore() {
        createSut()

        sut.setActive("MyPreset")

        #expect(rawStoreSpy.calls == [.saveActivePreset(RawActivePresetState(name: "MyPreset"))])
    }

    @Test
    mutating func setActive_nil_deletesActivePresetOnRawStore() {
        createSut()

        sut.setActive(nil)

        #expect(rawStoreSpy.calls == [.deleteActivePreset])
    }

    // MARK: - load

    @Test
    mutating func load_noStoredPreset_returnsNil() {
        createSut()

        #expect(sut.load(name: "absent") == nil)
    }

    @Test
    mutating func load_installedPlugin_resolvesFromLibraryWithStateAndBypass() {
        let component = AudioUnitComponent.fake()
        rawStoreSpy.presets = ["MyPreset": .fake(pluginSlots: [component.rawSlot(state: Data([0x01]), isBypassed: true)])]
        librarySpy.components = [component]
        createSut()

        #expect(sut.load(name: "MyPreset") == Preset.fake(
            name: "MyPreset",
            pluginSlots: [.fake(component: component, state: Data([0x01]), isBypassed: true, isInstalled: true)]
        ))
    }

    @Test
    mutating func load_installedPlugin_usesLibraryNameOverStoredName() throws {
        rawStoreSpy.presets = ["MyPreset": .fake(pluginSlots: [AudioUnitComponent.fake(name: "Stale Name").rawSlot()])]
        librarySpy.components = [.fake(name: "Live Name")]
        createSut()

        let slot = try #require(sut.load(name: "MyPreset")?.pluginSlots.first ?? nil)
        #expect(slot.component.name == "Live Name")
    }

    @Test
    mutating func load_pluginNotInLibrary_returnsNotInstalledWithStoredValues() throws {
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
        createSut()

        let slot = try #require(sut.load(name: "Orphan")?.pluginSlots.first ?? nil)
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
    mutating func load_pluginSlots_keepGapsAndResolveEach() {
        let component = AudioUnitComponent.fake()
        rawStoreSpy.presets = [
            "Chain": .fake(pluginSlots: [nil, component.rawSlot(), .fake(componentType: 99, name: "Gone")]),
        ]
        librarySpy.components = [component]
        createSut()

        #expect(sut.load(name: "Chain")?.pluginSlots == [
            nil,
            .fake(component: component, isInstalled: true),
            .fake(component: .fake(id: AudioUnitComponent.ID(type: 99, subType: 0, manufacturer: 0)), isInstalled: false),
        ])
    }

    // MARK: - save

    @Test
    mutating func save_installedPlugin_writesComponentIdentityStateAndBypass() {
        let component = AudioUnitComponent.fake()
        createSut()

        sut.save(.fake(
            name: "MyPreset",
            pluginSlots: [.fake(component: component, state: Data([0xBE, 0xEF]), isBypassed: true)
        ]))

        let expected = RawPreset.fake(pluginSlots: [component.rawSlot(state: Data([0xBE, 0xEF]), isBypassed: true)])
        #expect(rawStoreSpy.calls == [.save(expected, name: "MyPreset")])
    }

    @Test
    mutating func save_notInstalledPlugin_writesStoredValuesBack() {
        createSut()

        sut.save(.fake(
            name: "Orphan",
            pluginSlots: [.fake(
                component: .fake(
                    id: AudioUnitComponent.ID(type: 99, subType: 98, manufacturer: 97),
                    name: "Gone",
                    manufacturer: "Old Co"
                ),
                state: Data([0x02]),
                isBypassed: true,
                isInstalled: false
            )
        ]))

        let expected = RawPreset.fake(pluginSlots: [.fake(
            componentType: 99,
            componentSubType: 98,
            componentManufacturer: 97,
            name: "Gone",
            manufacturer: "Old Co",
            state: Data([0x02]),
            isBypassed: true
        )])
        #expect(rawStoreSpy.calls == [.save(expected, name: "Orphan")])
    }

    @Test
    mutating func save_pluginSlots_keepGaps() {
        let component = AudioUnitComponent.fake()
        createSut()

        sut.save(.fake(name: "Chain", pluginSlots: [nil, .fake(component: component)]))

        let expected = RawPreset.fake(pluginSlots: [nil, component.rawSlot()])
        #expect(rawStoreSpy.calls == [.save(expected, name: "Chain")])
    }

    @Test
    mutating func save_thenLoad_notInstalledPluginRoundTrips() throws {
        let preset = Preset.fake(
            name: "Orphan",
            pluginSlots: [.fake(
                component: .fake(id: AudioUnitComponent.ID(type: 99, subType: 0, manufacturer: 0), name: "Gone"),
                state: Data([0x03]),
                isInstalled: false
            )
        ])
        createSut()

        sut.save(preset)

        let loaded = sut.load(name: "Orphan")
        #expect(loaded == preset)
        let slot = try #require(loaded?.pluginSlots.first ?? nil)
        #expect(slot.component.name == "Gone")
    }

    // MARK: - rename

    @Test
    mutating func rename_movesFile() {
        let preset = RawPreset.fake(pluginSlots: [.fake(componentType: 5)])
        rawStoreSpy.presets = ["old": preset]
        createSut()

        sut.rename(from: "old", to: "new")

        #expect(rawStoreSpy.presets["old"] == nil)
        #expect(rawStoreSpy.presets["new"] == preset)
    }

    @Test
    mutating func rename_activeMatchesOld_followsToNew() {
        rawStoreSpy.presets = ["old": .fake()]
        rawStoreSpy.currentActivePreset = RawActivePresetState(name: "old")
        createSut()

        sut.rename(from: "old", to: "new")

        #expect(rawStoreSpy.currentActivePreset == RawActivePresetState(name: "new"))
    }

    @Test
    mutating func rename_activeDoesNotMatch_leavesActiveUnchanged() {
        rawStoreSpy.presets = ["old": .fake()]
        rawStoreSpy.currentActivePreset = RawActivePresetState(name: "keeper")
        createSut()

        sut.rename(from: "old", to: "new")

        #expect(rawStoreSpy.currentActivePreset == RawActivePresetState(name: "keeper"))
    }

    // MARK: - delete

    @Test
    mutating func delete_removesFile() {
        rawStoreSpy.presets = ["target": .fake()]
        createSut()

        sut.delete(name: "target")

        #expect(rawStoreSpy.presets["target"] == nil)
    }

    @Test
    mutating func delete_activeMatches_clearsActive() {
        rawStoreSpy.presets = ["target": .fake()]
        rawStoreSpy.currentActivePreset = RawActivePresetState(name: "target")
        createSut()

        sut.delete(name: "target")

        #expect(rawStoreSpy.currentActivePreset == nil)
    }

    @Test
    mutating func delete_activeDoesNotMatch_leavesActiveUnchanged() {
        rawStoreSpy.presets = ["target": .fake()]
        rawStoreSpy.currentActivePreset = RawActivePresetState(name: "keeper")
        createSut()

        sut.delete(name: "target")

        #expect(rawStoreSpy.currentActivePreset == RawActivePresetState(name: "keeper"))
    }
}

private extension AudioUnitComponent {
    func rawSlot(state: Data = Data(), isBypassed: Bool = false) -> RawPreset.PluginSlot {
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
