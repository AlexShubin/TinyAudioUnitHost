//
//  PresetProviderTests.swift
//  PresetKitTests
//
//  Created by Alex Shubin on 09.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioToolbox
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
        let component = AudioUnitComponent.fake(componentDescription: .fakeEffect)
        rawStoreSpy.presets = [
            "MyPreset": .fake(source: component.rawSlot(state: Data([0x01]))),
        ]
        librarySpy.components = [component]
        createSut()

        #expect(sut.presets == ["MyPreset"])
    }

    @Test
    mutating func presets_componentNotInLibrary_stillListsName() {
        let component = AudioUnitComponent.fake(componentDescription: .fakeEffect)
        rawStoreSpy.presets = [
            "Resolved": .fake(source: component.rawSlot()),
            "Orphan": .fake(source: .fake(componentType: 99, componentSubType: 99, componentManufacturer: 99)),
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
    mutating func load_installedSource_resolvesFromLibraryWithStateAndBypass() {
        let component = AudioUnitComponent.fake(componentDescription: .fakeEffect)
        rawStoreSpy.presets = ["MyPreset": .fake(source: component.rawSlot(state: Data([0x01]), isBypassed: true))]
        librarySpy.components = [component]
        createSut()

        #expect(sut.load(name: "MyPreset") == Preset.fake(
            name: "MyPreset",
            source: .fake(plugin: .installed(component), state: Data([0x01]), isBypassed: true),
            inserts: []
        ))
    }

    @Test
    mutating func load_installedSource_usesLibraryNameOverStoredName() {
        let component = AudioUnitComponent.fake(name: "Live Name", componentDescription: .fakeEffect)
        let stale = AudioUnitComponent.fake(name: "Stale Name", componentDescription: .fakeEffect)
        rawStoreSpy.presets = ["MyPreset": .fake(source: stale.rawSlot())]
        librarySpy.components = [component]
        createSut()

        guard case .installed(let resolved) = sut.load(name: "MyPreset")?.source?.plugin else {
            Issue.record("expected an installed source")
            return
        }
        #expect(resolved.name == "Live Name")
    }

    @Test
    mutating func load_pluginNotInLibrary_returnsMissingWithStoredValues() {
        rawStoreSpy.presets = [
            "Orphan": .fake(source: .fake(
                componentType: 99,
                componentSubType: 98,
                componentManufacturer: 97,
                name: "Gone",
                manufacturer: "Old Co",
                state: Data([0x02]),
                isBypassed: true
            )),
        ]
        createSut()

        #expect(sut.load(name: "Orphan") == Preset.fake(
            name: "Orphan",
            source: .fake(
                plugin: .missing(.fake(
                    name: "Gone",
                    manufacturer: "Old Co",
                    componentType: 99,
                    componentSubType: 98,
                    componentManufacturer: 97
                )),
                state: Data([0x02]),
                isBypassed: true
            ),
            inserts: []
        ))
    }

    @Test
    mutating func load_noSource_sourceIsNil() {
        rawStoreSpy.presets = ["InputOnly": .fake(source: nil)]
        createSut()

        #expect(sut.load(name: "InputOnly") == Preset.fake(name: "InputOnly", source: nil, inserts: []))
    }

    @Test
    mutating func load_inserts_keepPositionsAndResolveEach() {
        let component = AudioUnitComponent.fake(componentDescription: .fakeEffect)
        rawStoreSpy.presets = [
            "Chain": .fake(
                source: nil,
                inserts: [nil, component.rawSlot(), .fake(componentType: 99, name: "Gone")]
            ),
        ]
        librarySpy.components = [component]
        createSut()

        #expect(sut.load(name: "Chain")?.inserts == [
            nil,
            .fake(plugin: .installed(component)),
            .fake(plugin: .missing(.fake(name: "Gone", componentType: 99))),
        ])
    }

    // MARK: - save

    @Test
    mutating func save_installedSource_writesComponentIdentityStateAndBypass() {
        let component = AudioUnitComponent.fake(componentDescription: .fakeEffect)
        createSut()

        sut.save(.fake(
            name: "MyPreset",
            source: .fake(plugin: .installed(component), state: Data([0xBE, 0xEF]), isBypassed: true)
        ))

        let expected = RawPreset.fake(source: component.rawSlot(state: Data([0xBE, 0xEF]), isBypassed: true))
        #expect(rawStoreSpy.calls == [.save(expected, name: "MyPreset")])
    }

    @Test
    mutating func save_missingSource_writesStoredValuesBack() {
        createSut()

        sut.save(.fake(
            name: "Orphan",
            source: .fake(
                plugin: .missing(.fake(
                    name: "Gone",
                    manufacturer: "Old Co",
                    componentType: 99,
                    componentSubType: 98,
                    componentManufacturer: 97
                )),
                state: Data([0x02]),
                isBypassed: true
            )
        ))

        let expected = RawPreset.fake(source: .fake(
            componentType: 99,
            componentSubType: 98,
            componentManufacturer: 97,
            name: "Gone",
            manufacturer: "Old Co",
            state: Data([0x02]),
            isBypassed: true
        ))
        #expect(rawStoreSpy.calls == [.save(expected, name: "Orphan")])
    }

    @Test
    mutating func save_inserts_keepGaps() {
        let component = AudioUnitComponent.fake(componentDescription: .fakeEffect)
        createSut()

        sut.save(.fake(name: "Chain", source: nil, inserts: [nil, .fake(plugin: .installed(component))]))

        let expected = RawPreset.fake(source: nil, inserts: [nil, component.rawSlot()])
        #expect(rawStoreSpy.calls == [.save(expected, name: "Chain")])
    }

    @Test
    mutating func save_thenLoad_missingPluginRoundTrips() {
        let preset = Preset.fake(
            name: "Orphan",
            source: .fake(plugin: .missing(.fake(name: "Gone", componentType: 99)), state: Data([0x03]))
        )
        createSut()

        sut.save(preset)

        #expect(sut.load(name: "Orphan") == preset)
    }

    // MARK: - rename

    @Test
    mutating func rename_movesFile() {
        let preset = RawPreset.fake(source: .fake(componentType: 5))
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
        let desc = componentDescription
        return .fake(
            componentType: desc.componentType,
            componentSubType: desc.componentSubType,
            componentManufacturer: desc.componentManufacturer,
            name: name,
            manufacturer: manufacturer,
            state: state,
            isBypassed: isBypassed
        )
    }
}
