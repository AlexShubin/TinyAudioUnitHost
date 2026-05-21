//
//  SessionManagerTests.swift
//  TinyAudioUnitHostTests
//
//  Created by Alex Shubin on 21.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioSettingsKit
import AudioSettingsKitTestSupport
import AudioUnitsKit
import AudioUnitsKitTestSupport
import EngineKit
import EngineKitTestSupport
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
struct SessionManagerTests {
    var engineMock: EngineMock!
    var presetProviderMock: PresetProviderMock!
    var purchasesServiceMock: PurchasesServiceMock!
    var setupCheckerMock: SetupCheckerMock!
    var sut: SessionManagerType!

    init() {
        engineMock = EngineMock()
        presetProviderMock = PresetProviderMock()
        purchasesServiceMock = PurchasesServiceMock()
        setupCheckerMock = SetupCheckerMock()
    }

    mutating func createSut() {
        sut = SessionManager(
            engine: engineMock,
            presetProvider: presetProviderMock,
            purchasesService: purchasesServiceMock,
            setupChecker: setupCheckerMock
        )
    }

    // MARK: - start: setup gate

    @Test
    mutating func start_unmetEmpty_loadsActivePresetWhenAvailable() async {
        let component = AudioUnitComponent.fake(componentDescription: .fakeEffect)
        let loaded = LoadedAudioUnit.fake(component: component)
        presetProviderMock = PresetProviderMock(
            presets: ["foo": Preset(name: "foo", component: component, state: Data([0x01]))],
            activeName: "foo"
        )
        engineMock = EngineMock(loadResult: .success(loaded))
        createSut()

        await sut.start()
        await awaitChange { sut.content == .loaded(loaded) }

        #expect(sut.content == .loaded(loaded))
        #expect(sut.activeName == "foo")
        #expect(await engineMock.calls == [.load(component, Data([0x01]))])
    }

    @Test
    mutating func start_unmetEmpty_noActivePreset_contentEmpty() async {
        createSut()

        await sut.start()
        await awaitChange { sut.content == .empty }

        #expect(sut.content == .empty)
        #expect(sut.activeName == nil)
        #expect(await engineMock.calls == [])
    }

    @Test
    mutating func start_unmetEmpty_storedActiveStale_clearsActive() async {
        presetProviderMock = PresetProviderMock(activeName: "ghost")
        createSut()

        await sut.start()
        await awaitChange { sut.content == .empty }

        #expect(sut.content == .empty)
        #expect(sut.activeName == nil)
        #expect(presetProviderMock.calls.contains(.setActive(nil)))
    }

    @Test
    mutating func start_unmetNonEmpty_contentBecomesUnmet() async {
        setupCheckerMock = SetupCheckerMock(unmet: [.microphonePermission])
        createSut()

        await sut.start()
        await awaitChange { sut.content == .unmet([.microphonePermission]) }

        #expect(sut.content == .unmet([.microphonePermission]))
    }

    @Test
    mutating func start_unmetTransitionsToEmpty_loadsActivePreset() async {
        let component = AudioUnitComponent.fake(componentDescription: .fakeEffect)
        let loaded = LoadedAudioUnit.fake(component: component)
        presetProviderMock = PresetProviderMock(
            presets: ["foo": Preset(name: "foo", component: component, state: Data())],
            activeName: "foo"
        )
        engineMock = EngineMock(loadResult: .success(loaded))
        setupCheckerMock = SetupCheckerMock(unmet: [.microphonePermission])
        createSut()
        await sut.start()
        await awaitChange { sut.content == .unmet([.microphonePermission]) }

        await setupCheckerMock.emit([])

        await awaitChange { sut.content == .loaded(loaded) }
        #expect(sut.content == .loaded(loaded))
        #expect(sut.activeName == "foo")
    }

    @Test
    mutating func unmetKicksIn_overridesLoadedContent() async {
        let component = AudioUnitComponent.fake(componentDescription: .fakeEffect)
        let loaded = LoadedAudioUnit.fake(component: component)
        presetProviderMock = PresetProviderMock(
            presets: ["foo": Preset(name: "foo", component: component, state: Data())],
            activeName: "foo"
        )
        engineMock = EngineMock(loadResult: .success(loaded))
        createSut()
        await sut.start()
        await awaitChange { sut.content == .loaded(loaded) }

        await setupCheckerMock.emit([.outputDevice])

        await awaitChange { sut.content == .unmet([.outputDevice]) }
        #expect(sut.content == .unmet([.outputDevice]))
    }

    // MARK: - loadComponent

    @Test
    mutating func loadComponent_success_setsLoadedContent() async {
        let component = AudioUnitComponent.fake(componentDescription: .fakeEffect)
        let loaded = LoadedAudioUnit.fake(component: component)
        engineMock = EngineMock(loadResult: .success(loaded))
        createSut()

        await sut.loadComponent(component)

        #expect(sut.content == .loaded(loaded))
        #expect(await engineMock.calls == [.load(component, nil)])
    }

    @Test
    mutating func loadComponent_failure_setsFailedContent() async {
        let component = AudioUnitComponent.fake(componentDescription: .fakeEffect)
        engineMock = EngineMock(loadResult: .failure(.deviceUnavailable))
        createSut()

        await sut.loadComponent(component)

        if case .failed = sut.content { /* ok */ } else {
            Issue.record("expected .failed, got \(sut.content)")
        }
    }

    // MARK: - selectPreset

    @Test
    mutating func selectPreset_existing_setsActiveAndLoads() async {
        let component = AudioUnitComponent.fake(componentDescription: .fakeEffect)
        let loaded = LoadedAudioUnit.fake(component: component)
        presetProviderMock = PresetProviderMock(
            presets: ["foo": Preset(name: "foo", component: component, state: Data([0x07]))]
        )
        engineMock = EngineMock(loadResult: .success(loaded))
        createSut()

        await sut.selectPreset(name: "foo")

        #expect(sut.activeName == "foo")
        #expect(sut.content == .loaded(loaded))
        #expect(presetProviderMock.calls.contains(.setActive("foo")))
        #expect(await engineMock.calls == [.load(component, Data([0x07]))])
    }

    @Test
    mutating func selectPreset_missing_clearsContent() async {
        createSut()

        await sut.selectPreset(name: "ghost")

        #expect(sut.activeName == "ghost")
        #expect(sut.content == .empty)
        #expect(await engineMock.calls == [])
    }

    // MARK: - saveCurrentPreset

    @Test
    mutating func saveCurrentPreset_notLoaded_isNoOp() {
        createSut()

        sut.saveCurrentPreset()

        #expect(!presetProviderMock.calls.contains { if case .save = $0 { return true } else { return false } })
    }

    @Test
    mutating func saveCurrentPreset_happyPath_savesAndEmitsSavedEvent() async {
        let component = AudioUnitComponent.fake(componentDescription: .fakeEffect)
        let auMock = AUAudioUnitMock(fullState: Data([0xBE, 0xEF]))
        let loaded = LoadedAudioUnit.fake(component: component, audioUnit: auMock)
        presetProviderMock = PresetProviderMock(
            presets: ["foo": Preset(name: "foo", component: component, state: Data())],
            activeName: "foo"
        )
        engineMock = EngineMock(loadResult: .success(loaded))
        createSut()
        await sut.start()
        await awaitChange { sut.content == .loaded(loaded) }
        var events = sut.makeEventStream().makeAsyncIterator()

        sut.saveCurrentPreset()

        let saved = Preset(name: "foo", component: component, state: Data([0xBE, 0xEF]))
        #expect(presetProviderMock.calls.contains(.save(saved)))
        #expect(await events.next() == .saved)
    }

    // MARK: - restoreActivePreset

    @Test
    mutating func restoreActivePreset_noActive_isNoOp() async {
        createSut()

        await sut.restoreActivePreset()

        #expect(await engineMock.calls == [])
    }

    @Test
    mutating func restoreActivePreset_happyPath_emitsRestoredEvent() async {
        let component = AudioUnitComponent.fake(componentDescription: .fakeEffect)
        let loaded = LoadedAudioUnit.fake(component: component)
        presetProviderMock = PresetProviderMock(
            presets: ["foo": Preset(name: "foo", component: component, state: Data([0x09]))],
            activeName: "foo"
        )
        engineMock = EngineMock(loadResult: .success(loaded))
        createSut()
        await sut.start()
        await awaitChange { sut.content == .loaded(loaded) }
        var events = sut.makeEventStream().makeAsyncIterator()

        await sut.restoreActivePreset()

        #expect(sut.content == .loaded(loaded))
        #expect(await events.next() == .restored)
    }

    // MARK: - saveAsNewPreset

    @Test
    mutating func saveAsNewPreset_notLoaded_isNoOp() {
        createSut()

        sut.saveAsNewPreset(name: "anything")

        #expect(presetProviderMock.storedPresets.isEmpty)
    }

    @Test
    mutating func saveAsNewPreset_happyPath_savesSetsActiveAndEmits() async {
        let component = AudioUnitComponent.fake(componentDescription: .fakeEffect)
        let auMock = AUAudioUnitMock(fullState: Data([0xAA]))
        let loaded = LoadedAudioUnit.fake(component: component, audioUnit: auMock)
        engineMock = EngineMock(loadResult: .success(loaded))
        createSut()
        await sut.loadComponent(component)
        var events = sut.makeEventStream().makeAsyncIterator()

        sut.saveAsNewPreset(name: "MyNew")

        #expect(sut.activeName == "MyNew")
        #expect(presetProviderMock.currentActiveName == "MyNew")
        #expect(await events.next() == .saved)
    }

    // MARK: - renamePreset

    @Test
    mutating func renamePreset_forwardsToProviderAndRefreshes() {
        presetProviderMock = PresetProviderMock(
            presets: ["old": Preset.fake(name: "old")],
            activeName: "old"
        )
        createSut()

        sut.renamePreset(from: "old", to: "new")

        #expect(presetProviderMock.calls.contains(.rename(from: "old", to: "new")))
        #expect(sut.activeName == "new")
    }

    // MARK: - deletePreset

    @Test
    mutating func deletePreset_forwardsAndClearsActiveIfMatched() {
        presetProviderMock = PresetProviderMock(
            presets: ["target": Preset.fake(name: "target")],
            activeName: "target"
        )
        createSut()

        sut.deletePreset(name: "target")

        #expect(presetProviderMock.calls.contains(.delete(name: "target")))
        #expect(sut.activeName == nil)
    }

    // MARK: - requestSaveAs

    @Test
    mutating func requestSaveAs_pro_emitsRequestSaveAsDialog() async {
        purchasesServiceMock = PurchasesServiceMock(isPro: true)
        createSut()
        var events = sut.makeEventStream().makeAsyncIterator()

        await sut.requestSaveAs()

        #expect(await events.next() == .requestSaveAsDialog)
    }

    @Test
    mutating func requestSaveAs_freeBelowCap_emitsRequestSaveAsDialog() async {
        purchasesServiceMock = PurchasesServiceMock(isPro: false)
        presetProviderMock = PresetProviderMock(presets: ["one": Preset.fake(name: "one")])
        createSut()
        await sut.start()
        await awaitChange { sut.content == .empty }
        var events = sut.makeEventStream().makeAsyncIterator()

        await sut.requestSaveAs()

        #expect(await events.next() == .requestSaveAsDialog)
    }

    @Test
    mutating func requestSaveAs_freeAtCap_emitsRequestProUpgrade() async {
        purchasesServiceMock = PurchasesServiceMock(isPro: false)
        presetProviderMock = PresetProviderMock(presets: [
            "a": Preset.fake(name: "a"),
            "b": Preset.fake(name: "b"),
        ])
        createSut()
        await sut.start()
        await awaitChange { sut.content == .empty }
        var events = sut.makeEventStream().makeAsyncIterator()

        await sut.requestSaveAs()

        #expect(await events.next() == .requestProUpgrade)
    }

    // MARK: - free-tier slicing

    @Test
    mutating func presets_freeUser_slicesToFirstTwo() async {
        purchasesServiceMock = PurchasesServiceMock(isPro: false)
        presetProviderMock = PresetProviderMock(presets: [
            "a": Preset.fake(name: "a"),
            "b": Preset.fake(name: "b"),
            "c": Preset.fake(name: "c"),
        ])
        createSut()
        await sut.start()
        await awaitChange { sut.content == .empty }

        #expect(sut.presets.map(\.name) == ["a", "b"])
    }

    @Test
    mutating func presets_proUser_returnsAll() async {
        purchasesServiceMock = PurchasesServiceMock(isPro: true)
        presetProviderMock = PresetProviderMock(presets: [
            "a": Preset.fake(name: "a"),
            "b": Preset.fake(name: "b"),
            "c": Preset.fake(name: "c"),
        ])
        createSut()
        await sut.start()
        await awaitChange { sut.content == .empty }

        #expect(sut.presets.map(\.name) == ["a", "b", "c"])
    }

    // MARK: - Helpers

    /// Loops through observation-tracking waits until the predicate is true.
    /// The tracker is single-shot, so re-register after each fire.
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
