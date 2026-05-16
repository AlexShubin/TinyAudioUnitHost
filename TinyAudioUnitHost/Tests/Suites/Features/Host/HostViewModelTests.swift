//
//  HostViewModelTests.swift
//  TinyAudioUnitHostTests
//
//  Created by Alex Shubin on 04.05.26.
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
struct HostViewModelTests {
    var libraryMock: AudioUnitComponentsLibraryMock!
    var engineMock: EngineMock!
    var presetProviderMock: PresetProviderMock!
    var setupCheckerMock: SetupCheckerMock!
    var sut: HostViewModelType!

    init() {
        libraryMock = AudioUnitComponentsLibraryMock()
        engineMock = EngineMock()
        presetProviderMock = PresetProviderMock()
        setupCheckerMock = SetupCheckerMock()
    }

    mutating func createSut() {
        sut = HostViewModel(
            library: libraryMock,
            engine: engineMock,
            presetProvider: presetProviderMock,
            setupChecker: setupCheckerMock
        )
    }

    private func awaitUnmetChange(_ trigger: @MainActor @escaping () async -> Void) async {
        await withCheckedContinuation { continuation in
            withObservationTracking {
                _ = sut.unmetRequirements
            } onChange: {
                continuation.resume()
            }
            Task { @MainActor in await trigger() }
        }
    }

    // MARK: - task

    @Test
    mutating func task_groupsLibraryComponentsByManufacturerAlphabetically() async {
        let appleEffect = AudioUnitComponent.fake(name: "Dynamics", manufacturer: "Apple")
        let zoomEffect = AudioUnitComponent.fake(name: "Reverb", manufacturer: "Zoom")
        let kornEffect = AudioUnitComponent.fake(name: "Compressor", manufacturer: "Korn")
        libraryMock.components = [zoomEffect, appleEffect, kornEffect]
        createSut()

        await sut.accept(action: .task)

        #expect(sut.groups.map(\.manufacturer) == ["Apple", "Korn", "Zoom"])
    }

    @Test
    mutating func task_groupsContainTheirComponents() async {
        let apple1 = AudioUnitComponent.fake(name: "Dynamics", manufacturer: "Apple")
        let apple2 = AudioUnitComponent.fake(name: "Reverb", manufacturer: "Apple")
        let other = AudioUnitComponent.fake(name: "Other", manufacturer: "Other")
        libraryMock.components = [apple1, other, apple2]
        createSut()

        await sut.accept(action: .task)

        let appleGroup = sut.groups.first { $0.manufacturer == "Apple" }
        #expect(appleGroup?.components == [apple1, apple2])
    }

    @Test
    mutating func task_groupsCollapsedByDefault() async {
        libraryMock.components = [.fake(manufacturer: "Apple")]
        createSut()

        await sut.accept(action: .task)

        #expect(sut.groups.allSatisfy { !$0.isExpanded })
    }

    @Test
    mutating func task_emptyLibrary_emptyGroups() async {
        createSut()

        await sut.accept(action: .task)

        #expect(sut.groups == [])
    }

    @Test
    mutating func task_noStoredPreset_doesNotLoadEngine() async {
        createSut()

        await sut.accept(action: .task)

        #expect(sut.content == .empty)
        #expect(sut.selectedComponent == nil)
        #expect(await presetProviderMock.calls == [.loadDefault])
        #expect(await engineMock.calls == [])
    }

    @Test
    mutating func task_storedPresetLoadsSuccessfully_setsContentAndSelectedComponent() async {
        let component = AudioUnitComponent.fake(name: "Dyn")
        let loaded = LoadedAudioUnit.fake(component: component)
        presetProviderMock = PresetProviderMock(defaultPreset: Preset(component: component, state: Data([0x01])))
        engineMock = EngineMock(loadResult: .success(loaded))
        createSut()

        await sut.accept(action: .task)

        #expect(sut.selectedComponent == component)
        #expect(sut.content == .loaded(loaded))
        #expect(await engineMock.calls == [.load(component, Data([0x01]))])
    }

    @Test
    mutating func task_calledTwice_doesNotReloadPreset() async {
        let component = AudioUnitComponent.fake()
        let loaded = LoadedAudioUnit.fake(component: component)
        presetProviderMock = PresetProviderMock(defaultPreset: Preset(component: component, state: Data()))
        engineMock = EngineMock(loadResult: .success(loaded))
        createSut()

        await sut.accept(action: .task)
        await sut.accept(action: .task)

        #expect(await presetProviderMock.calls == [.loadDefault])
        #expect(await engineMock.calls == [.load(component, Data())])
    }

    // MARK: - selected

    @Test
    mutating func selected_setsSelectedComponentImmediately() async {
        let component = AudioUnitComponent.fake(name: "Dynamics")
        createSut()

        await sut.accept(action: .selected(component))

        #expect(sut.selectedComponent == component)
    }

    @Test
    mutating func selected_engineLoadSucceeds_setsContentToLoaded() async {
        let component = AudioUnitComponent.fake(name: "Dynamics")
        let loaded = LoadedAudioUnit.fake(component: component)
        engineMock = EngineMock(loadResult: .success(loaded))
        createSut()

        await sut.accept(action: .selected(component))

        #expect(sut.content == .loaded(loaded))
    }

    @Test
    mutating func selected_engineLoadFails_setsContentToFailed() async {
        let component = AudioUnitComponent.fake(name: "Dynamics")
        // engineMock defaults to .failure(.audioUnitInstantiationFailed)
        createSut()

        await sut.accept(action: .selected(component))

        #expect(sut.content == .failed("Couldn't load this audio unit."))
    }

    @Test
    mutating func selected_engineDeviceUnavailable_setsFailedWithDeviceMessage() async {
        let component = AudioUnitComponent.fake(name: "Dynamics")
        engineMock = EngineMock(loadResult: .failure(.deviceUnavailable))
        createSut()

        await sut.accept(action: .selected(component))

        #expect(sut.content == .failed("Audio device is unavailable. Check Settings."))
    }

    @Test
    mutating func selected_callsEngineLoadWithComponent() async {
        let component = AudioUnitComponent.fake(name: "Dynamics")
        createSut()

        await sut.accept(action: .selected(component))

        #expect(await engineMock.calls == [.load(component, nil)])
    }

    // MARK: - saveCurrentPreset

    @Test
    mutating func saveCurrentPreset_loaded_writesPresetThroughProvider() async {
        let component = AudioUnitComponent.fake(name: "Dyn")
        let auMock = AUAudioUnitMock(fullState: Data([0xBE, 0xEF]))
        let loaded = LoadedAudioUnit.fake(component: component, audioUnit: auMock)
        engineMock = EngineMock(loadResult: .success(loaded))
        createSut()
        await sut.accept(action: .selected(component))

        await sut.accept(action: .saveCurrentPreset)

        let expected = Preset(component: component, state: Data([0xBE, 0xEF]))
        #expect(await presetProviderMock.calls == [.saveDefault(expected)])
    }

    @Test
    mutating func saveCurrentPreset_emptyContent_doesNothing() async {
        createSut()

        await sut.accept(action: .saveCurrentPreset)

        #expect(await presetProviderMock.calls == [])
        #expect(await engineMock.calls == [])
        #expect(sut.saveFeedbackId == nil)
    }

    @Test
    mutating func saveCurrentPreset_loaded_setsSaveFeedbackId() async {
        let component = AudioUnitComponent.fake(name: "Dyn")
        let loaded = LoadedAudioUnit.fake(component: component)
        engineMock = EngineMock(loadResult: .success(loaded))
        createSut()
        await sut.accept(action: .selected(component))

        await sut.accept(action: .saveCurrentPreset)

        #expect(sut.saveFeedbackId != nil)
    }

    @Test
    mutating func dismissSaveFeedback_clearsSaveFeedbackId() async {
        let component = AudioUnitComponent.fake(name: "Dyn")
        let loaded = LoadedAudioUnit.fake(component: component)
        engineMock = EngineMock(loadResult: .success(loaded))
        createSut()
        await sut.accept(action: .selected(component))
        await sut.accept(action: .saveCurrentPreset)
        #expect(sut.saveFeedbackId != nil)

        await sut.accept(action: .dismissSaveFeedback)

        #expect(sut.saveFeedbackId == nil)
    }

    // MARK: - setup gating

    @Test
    mutating func selected_notReady_doesNotLoadEngine() async {
        createSut()
        let sut = sut!
        let mock = setupCheckerMock!

        await awaitUnmetChange { await mock.emit([.microphonePermission]) }
        #expect(!sut.isReady)

        await sut.accept(action: .selected(.fake()))

        #expect(await engineMock.calls == [])
    }

    @Test
    mutating func setupChecker_yields_updatesUnmetRequirements() async {
        createSut()
        let sut = sut!
        let mock = setupCheckerMock!

        await awaitUnmetChange { await mock.emit([.outputDevice]) }

        #expect(sut.unmetRequirements == [.outputDevice])
        #expect(!sut.isReady)
    }

    // MARK: - restorePreset

    @Test
    mutating func restorePreset_callsPresetProviderLoadDefault() async {
        createSut()

        await sut.accept(action: .restorePreset)

        #expect(await presetProviderMock.calls == [.loadDefault])
    }

    @Test
    mutating func restorePreset_presetLoadsSuccessfully_setsContentAndSelectedComponent() async {
        let component = AudioUnitComponent.fake(name: "Saved")
        let loaded = LoadedAudioUnit.fake(component: component)
        presetProviderMock = PresetProviderMock(defaultPreset: Preset(component: component, state: Data()))
        engineMock = EngineMock(loadResult: .success(loaded))
        createSut()

        await sut.accept(action: .restorePreset)

        #expect(sut.selectedComponent == component)
        #expect(sut.content == .loaded(loaded))
    }

    @Test
    mutating func restorePreset_noDefault_clearsToEmpty() async {
        let component = AudioUnitComponent.fake()
        let loaded = LoadedAudioUnit.fake(component: component)
        engineMock = EngineMock(loadResult: .success(loaded))
        createSut()
        await sut.accept(action: .selected(component))
        #expect(sut.content == .loaded(loaded))

        await sut.accept(action: .restorePreset)

        #expect(sut.selectedComponent == nil)
        #expect(sut.content == .empty)
    }

    // MARK: - groupExpansionChanged

    @Test
    mutating func groupExpansionChanged_togglesGroupExpansion() async {
        libraryMock.components = [
            .fake(manufacturer: "Apple"),
            .fake(manufacturer: "Zoom"),
        ]
        createSut()
        await sut.accept(action: .task)

        await sut.accept(action: .groupExpansionChanged(manufacturer: "Apple", isExpanded: true))

        let appleGroup = sut.groups.first { $0.manufacturer == "Apple" }
        let zoomGroup = sut.groups.first { $0.manufacturer == "Zoom" }
        #expect(appleGroup?.isExpanded == true)
        #expect(zoomGroup?.isExpanded == false)
    }

    @Test
    mutating func groupExpansionChanged_canCollapseAfterExpanding() async {
        libraryMock.components = [.fake(manufacturer: "Apple")]
        createSut()
        await sut.accept(action: .task)
        await sut.accept(action: .groupExpansionChanged(manufacturer: "Apple", isExpanded: true))

        await sut.accept(action: .groupExpansionChanged(manufacturer: "Apple", isExpanded: false))

        #expect(sut.groups.first?.isExpanded == false)
    }

    @Test
    mutating func groupExpansionChanged_unknownManufacturer_noOp() async {
        libraryMock.components = [.fake(manufacturer: "Apple")]
        createSut()
        await sut.accept(action: .task)
        let groupsBefore = sut.groups

        await sut.accept(action: .groupExpansionChanged(manufacturer: "Unknown", isExpanded: true))

        #expect(sut.groups == groupsBefore)
    }
}
