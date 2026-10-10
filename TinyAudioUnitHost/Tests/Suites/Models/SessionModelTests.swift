//
//  SessionModelTests.swift
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
import PresetKit
import PresetKitTestSupport
import Testing
@testable import TinyAudioUnitHost

@MainActor
@Suite
struct SessionModelTests {
    var engineSpy: EngineSpy!
    var presetProviderSpy: PresetProviderSpy!
    var setupCheckerSpy: SetupCheckerSpy!
    var sut: SessionModelType!

    init() {
        engineSpy = EngineSpy()
        presetProviderSpy = PresetProviderSpy()
        setupCheckerSpy = SetupCheckerSpy()
    }

    mutating func createSut() {
        sut = SessionModel(
            engine: engineSpy,
            presetProvider: presetProviderSpy,
            setupChecker: setupCheckerSpy
        )
    }

    // MARK: - init

    @Test
    mutating func init_contentIsIdle() {
        createSut()

        #expect(sut.content == .idle)
    }

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

    // MARK: - refreshSetup: setup gate

    @Test
    mutating func refreshSetup_idle_unmetEmpty_loadsActivePresetWhenAvailable() async {
        let component = AudioUnitComponent.fake(componentDescription: .fakeEffect)
        let loaded = LoadedAudioUnit.fake(component: component)
        presetProviderSpy = PresetProviderSpy(
            presets: ["foo": Preset(name: "foo", component: component, state: Data([0x01]))],
            activeName: "foo"
        )
        engineSpy = EngineSpy(loadResult: .success(loaded))
        createSut()

        await sut.refreshSetup()
        #expect(sut.content == .loaded(loaded))
        #expect(sut.activeName == "foo")
        #expect(engineSpy.calls == [.load(component, Data([0x01]))])
    }

    @Test
    mutating func refreshSetup_idle_unmetEmpty_noActivePreset_contentEmpty() async {
        createSut()

        await sut.refreshSetup()
        #expect(sut.content == .empty)
        #expect(sut.activeName == nil)
        #expect(engineSpy.calls == [])
    }

    @Test
    mutating func refreshSetup_idle_unmetEmpty_storedActiveStale_keepsActiveAndFails() async {
        presetProviderSpy = PresetProviderSpy(activeName: "ghost")
        createSut()

        await sut.refreshSetup()
        #expect(sut.content == .failed("Couldn't load this preset."))
        #expect(sut.activeName == "ghost")
        #expect(!presetProviderSpy.calls.contains(.setActive(nil)))
    }

    @Test
    mutating func refreshSetup_idle_unmetNonEmpty_contentBecomesUnmet() async {
        setupCheckerSpy.checkResult = [.microphonePermission]
        createSut()

        await sut.refreshSetup()
        #expect(sut.content == .unmet([.microphonePermission]))
    }

    @Test
    mutating func refreshSetup_unmetClears_loadsActivePreset() async {
        let component = AudioUnitComponent.fake(componentDescription: .fakeEffect)
        let loaded = LoadedAudioUnit.fake(component: component)
        presetProviderSpy = PresetProviderSpy(
            presets: ["foo": Preset(name: "foo", component: component, state: Data())],
            activeName: "foo"
        )
        engineSpy = EngineSpy(loadResult: .success(loaded))
        setupCheckerSpy.checkResult = [.microphonePermission]
        createSut()
        await sut.refreshSetup()
        #expect(sut.content == .unmet([.microphonePermission]))

        setupCheckerSpy.checkResult = []
        await sut.refreshSetup()

        #expect(sut.content == .loaded(loaded))
        #expect(sut.activeName == "foo")
    }

    @Test
    mutating func refreshSetup_unmet_overridesLoadedContent() async {
        let component = AudioUnitComponent.fake(componentDescription: .fakeEffect)
        let loaded = LoadedAudioUnit.fake(component: component)
        presetProviderSpy = PresetProviderSpy(
            presets: ["foo": Preset(name: "foo", component: component, state: Data())],
            activeName: "foo"
        )
        engineSpy = EngineSpy(loadResult: .success(loaded))
        createSut()
        await sut.refreshSetup()
        #expect(sut.content == .loaded(loaded))

        setupCheckerSpy.checkResult = [.noOutputDevice]
        await sut.refreshSetup()

        #expect(sut.content == .unmet([.noOutputDevice]))
    }

    @Test
    mutating func refreshSetup_whileLoading_doesNotStartSecondLoad() async {
        let component = AudioUnitComponent.fake(componentDescription: .fakeEffect)
        let loaded = LoadedAudioUnit.fake(component: component)
        presetProviderSpy = PresetProviderSpy(
            presets: ["foo": Preset(name: "foo", component: component, state: Data())],
            activeName: "foo"
        )
        engineSpy = EngineSpy(loadResult: .success(loaded))
        createSut()
        let session = sut!
        engineSpy.onLoad = {
            #expect(await session.content == .loading)
            await session.refreshSetup()
        }

        await sut.refreshSetup()

        #expect(engineSpy.calls == [.load(component, Data())])
        #expect(sut.content == .loaded(loaded))
    }

    @Test
    mutating func refreshSetup_whileLoading_unmetWinsOverLoadResult() async {
        let component = AudioUnitComponent.fake(componentDescription: .fakeEffect)
        presetProviderSpy = PresetProviderSpy(
            presets: ["foo": Preset(name: "foo", component: component, state: Data())],
            activeName: "foo"
        )
        engineSpy = EngineSpy(loadResult: .success(.fake(component: component)))
        createSut()
        let session = sut!
        let setupChecker = setupCheckerSpy!
        engineSpy.onLoad = {
            setupChecker.checkResult = [.noOutputDevice]
            await session.refreshSetup()
        }

        await sut.refreshSetup()

        #expect(sut.content == .unmet([.noOutputDevice]))
    }

    // MARK: - loadComponent

    @Test
    mutating func loadComponent_success_setsLoadedContent() async {
        let component = AudioUnitComponent.fake(componentDescription: .fakeEffect)
        let loaded = LoadedAudioUnit.fake(component: component)
        engineSpy = EngineSpy(loadResult: .success(loaded))
        createSut()

        await sut.loadComponent(component)

        #expect(sut.content == .loaded(loaded))
        #expect(engineSpy.calls == [.load(component, nil)])
    }

    @Test
    mutating func loadComponent_failure_setsFailedContent() async {
        let component = AudioUnitComponent.fake(componentDescription: .fakeEffect)
        engineSpy = EngineSpy(loadResult: .failure(.deviceUnavailable))
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
        presetProviderSpy = PresetProviderSpy(
            presets: ["foo": Preset(name: "foo", component: component, state: Data([0x07]))]
        )
        engineSpy = EngineSpy(loadResult: .success(loaded))
        createSut()

        await sut.selectPreset(name: "foo")

        #expect(sut.activeName == "foo")
        #expect(sut.content == .loaded(loaded))
        #expect(presetProviderSpy.calls.contains(.setActive("foo")))
        #expect(engineSpy.calls == [.load(component, Data([0x07]))])
    }

    @Test
    mutating func selectPreset_missing_setsFailedContent() async {
        createSut()

        await sut.selectPreset(name: "ghost")

        #expect(sut.activeName == "ghost")
        #expect(sut.content == .failed("Couldn't load this preset."))
        #expect(engineSpy.calls == [])
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
    mutating func saveCurrentPreset_happyPath_savesAndNotifiesDelegate() async {
        let component = AudioUnitComponent.fake(componentDescription: .fakeEffect)
        let audioUnit = AUAudioUnitWrapper(fullState: Data([0xBE, 0xEF]))
        let loaded = LoadedAudioUnit.fake(component: component, audioUnit: audioUnit)
        presetProviderSpy = PresetProviderSpy(
            presets: ["foo": Preset(name: "foo", component: component, state: Data())],
            activeName: "foo"
        )
        engineSpy = EngineSpy(loadResult: .success(loaded))
        createSut()
        await sut.refreshSetup()
        #expect(sut.content == .loaded(loaded))

        sut.saveCurrentPreset()

        let saved = Preset(name: "foo", component: component, state: Data([0xBE, 0xEF]))
        #expect(presetProviderSpy.calls.contains(.save(saved)))
        #expect(sut.presetEvent?.kind == .saved)
    }

    // MARK: - restoreActivePreset

    @Test
    mutating func restoreActivePreset_noActive_isNoOp() async {
        createSut()

        await sut.restoreActivePreset()

        #expect(engineSpy.calls == [])
        #expect(sut.presetEvent == nil)
    }

    @Test
    mutating func restoreActivePreset_happyPath_notifiesDelegate() async {
        let component = AudioUnitComponent.fake(componentDescription: .fakeEffect)
        let loaded = LoadedAudioUnit.fake(component: component)
        presetProviderSpy = PresetProviderSpy(
            presets: ["foo": Preset(name: "foo", component: component, state: Data([0x09]))],
            activeName: "foo"
        )
        engineSpy = EngineSpy(loadResult: .success(loaded))
        createSut()
        await sut.refreshSetup()
        #expect(sut.content == .loaded(loaded))

        await sut.restoreActivePreset()

        #expect(sut.content == .loaded(loaded))
        #expect(sut.presetEvent?.kind == .restored)
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
    mutating func saveAsNewPreset_happyPath_savesSetsActiveAndNotifiesDelegate() async {
        let component = AudioUnitComponent.fake(componentDescription: .fakeEffect)
        let audioUnit = AUAudioUnitWrapper(fullState: Data([0xAA]))
        let loaded = LoadedAudioUnit.fake(component: component, audioUnit: audioUnit)
        engineSpy = EngineSpy(loadResult: .success(loaded))
        createSut()
        await sut.loadComponent(component)

        sut.saveAsNewPreset(name: "MyNew")

        #expect(sut.activeName == "MyNew")
        #expect(presetProviderSpy.currentActiveName == "MyNew")
        #expect(sut.presetEvent?.kind == .saved)
    }

    // MARK: - presets exposure (no longer capped at this layer)

    // MARK: - acknowledgePresetEvent

    @Test
    mutating func acknowledgePresetEvent_clearsEvent() async {
        let component = AudioUnitComponent.fake(componentDescription: .fakeEffect)
        let loaded = LoadedAudioUnit.fake(component: component, audioUnit: AUAudioUnitWrapper(fullState: Data([0x01])))
        presetProviderSpy = PresetProviderSpy(
            presets: ["foo": Preset(name: "foo", component: component, state: Data())],
            activeName: "foo"
        )
        engineSpy = EngineSpy(loadResult: .success(loaded))
        createSut()
        await sut.refreshSetup()
        sut.saveCurrentPreset()
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
        #expect(sut.activeName == "new")
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
        #expect(sut.activeName == nil)
    }

}
