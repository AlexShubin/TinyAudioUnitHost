//
//  HostViewModelTests.swift
//  TinyAudioUnitHostTests
//
//  Created by Alex Shubin on 04.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

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
    var engineMock: EngineMock!
    var libraryMock: AudioUnitComponentsLibraryMock!
    var presetProviderMock: PresetProviderMock!
    var quitCoordinator: QuitCoordinator!
    var sut: HostViewModelType!

    init() {
        engineMock = EngineMock()
        libraryMock = AudioUnitComponentsLibraryMock()
        presetProviderMock = PresetProviderMock()
        quitCoordinator = QuitCoordinator()
    }

    mutating func createSut() {
        sut = HostViewModel(
            engine: engineMock,
            library: libraryMock,
            presetProvider: presetProviderMock,
            quitCoordinator: quitCoordinator
        )
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
    mutating func task_noSavedPreset_doesNotCallEngine() async {
        createSut()

        await sut.accept(action: .task)

        #expect(await engineMock.calls == [])
    }

    @Test
    mutating func task_savedPresetExists_loadsThroughEngineWithComponentAndState() async {
        let component = AudioUnitComponent.fake()
        let state = Data([0xDE, 0xAD])
        presetProviderMock = PresetProviderMock(presets: ["default": Preset(component: component, state: state)])
        let loaded = LoadedAudioUnit.fake(component: component)
        await engineMock.setLoadResult(loaded)
        createSut()

        await sut.accept(action: .task)

        #expect(await engineMock.calls == [.load(component, state)])
    }

    @Test
    mutating func task_savedPresetExists_setsLoadedContentAndSelectedComponent() async {
        let component = AudioUnitComponent.fake(name: "Dyn")
        let preset = Preset(component: component, state: Data([0x01]))
        presetProviderMock = PresetProviderMock(presets: ["default": preset])
        let loaded = LoadedAudioUnit.fake(component: component)
        await engineMock.setLoadResult(loaded)
        createSut()

        await sut.accept(action: .task)

        #expect(sut.selectedComponent == component)
        #expect(sut.content == .loaded(loaded))
    }

    @Test
    mutating func task_savedPresetExists_doesNotMarkModified() async {
        let component = AudioUnitComponent.fake()
        let preset = Preset(component: component, state: Data())
        presetProviderMock = PresetProviderMock(presets: ["default": preset])
        await engineMock.setLoadResult(LoadedAudioUnit.fake(component: component))
        createSut()

        await sut.accept(action: .task)

        #expect(sut.presetTitle == "Preset: Default")
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
        await engineMock.setLoadResult(loaded)
        createSut()

        await sut.accept(action: .selected(component))

        #expect(sut.content == .loaded(loaded))
    }

    @Test
    mutating func selected_engineLoadReturnsNil_staysInLoading() async {
        let component = AudioUnitComponent.fake(name: "Dynamics")
        createSut()

        await sut.accept(action: .selected(component))

        #expect(sut.content == .loading)
    }

    @Test
    mutating func selected_callsEngineLoadWithComponentAndNilState() async {
        let component = AudioUnitComponent.fake(name: "Dynamics")
        createSut()

        await sut.accept(action: .selected(component))

        #expect(await engineMock.calls == [.load(component, nil)])
    }

    @Test
    mutating func selected_marksTitleModified() async {
        let component = AudioUnitComponent.fake(name: "Dynamics")
        createSut()

        await sut.accept(action: .selected(component))

        #expect(sut.presetTitle == "Preset: Default*")
    }

    // MARK: - saveCurrentPreset

    @Test
    mutating func saveCurrentPreset_loadedContent_savesViaProviderAndClearsTitle() async {
        let component = AudioUnitComponent.fake(name: "Dyn")
        let loaded = LoadedAudioUnit.fake(component: component)
        await engineMock.setLoadResult(loaded)
        createSut()
        await sut.accept(action: .selected(component))
        #expect(sut.presetTitle == "Preset: Default*")

        await sut.accept(action: .saveCurrentPreset)

        #expect(sut.presetTitle == "Preset: Default")
        let calls = await presetProviderMock.calls
        #expect(calls.contains { call in
            if case .save(let preset, let name) = call {
                return preset.component == component && name == "default"
            }
            return false
        })
    }

    @Test
    mutating func saveCurrentPreset_emptyContent_doesNotCallProvider() async {
        createSut()

        await sut.accept(action: .saveCurrentPreset)

        #expect(await presetProviderMock.calls == [])
    }

    @Test
    mutating func task_savedPreset_paramChange_marksTitleModified() async {
        let component = AudioUnitComponent.fake()
        let preset = Preset(component: component, state: Data())
        presetProviderMock = PresetProviderMock(presets: ["default": preset])
        let auMock = AUAudioUnitMock()
        await engineMock.setLoadResult(LoadedAudioUnit.fake(component: component, audioUnit: auMock))
        createSut()

        await sut.accept(action: .task)
        #expect(sut.presetTitle == "Preset: Default")

        auMock.triggerOnChange()
        try? await Task.sleep(for: .milliseconds(20))

        #expect(sut.presetTitle == "Preset: Default*")
    }

    @Test
    mutating func saveCurrentPreset_paramChangeAfterSave_marksTitleModified() async {
        let component = AudioUnitComponent.fake()
        let auMock = AUAudioUnitMock(fullState: Data([0x42]))
        await engineMock.setLoadResult(LoadedAudioUnit.fake(component: component, audioUnit: auMock))
        createSut()
        await sut.accept(action: .selected(component))
        #expect(sut.presetTitle == "Preset: Default*")
        await sut.accept(action: .saveCurrentPreset)
        #expect(sut.presetTitle == "Preset: Default")

        auMock.triggerOnChange()
        try? await Task.sleep(for: .milliseconds(20))

        #expect(sut.presetTitle == "Preset: Default*")
    }

    // MARK: - presetTitle

    @Test
    mutating func presetTitle_initialState_showsDefaultWithoutAsterisk() async {
        createSut()

        #expect(sut.presetTitle == "Preset: Default")
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

    // MARK: - quit

    @Test
    mutating func quitRequest_clean_resolvesProceedTrueWithoutShowingAlert() async {
        createSut()

        let proceed = await quitCoordinator.requestQuit()

        #expect(proceed == true)
        #expect(sut.isQuitAlertShown == false)
    }

    @Test
    mutating func quitRequest_dirty_showsAlert() async {
        let component = AudioUnitComponent.fake()
        createSut()
        await sut.accept(action: .selected(component))
        let coordinator = quitCoordinator!

        let proceedTask = Task { await coordinator.requestQuit() }
        try? await Task.sleep(for: .milliseconds(20))

        #expect(sut.isQuitAlertShown == true)

        await sut.accept(action: .quit(.cancel))
        _ = await proceedTask.value
    }

    @Test
    mutating func quit_save_persistsPresetAndResolvesProceedTrue() async {
        let component = AudioUnitComponent.fake()
        let auMock = AUAudioUnitMock(fullState: Data([0x42]))
        await engineMock.setLoadResult(LoadedAudioUnit.fake(component: component, audioUnit: auMock))
        createSut()
        await sut.accept(action: .selected(component))
        let coordinator = quitCoordinator!

        let proceedTask = Task { await coordinator.requestQuit() }
        try? await Task.sleep(for: .milliseconds(20))

        await sut.accept(action: .quit(.save))

        #expect(await proceedTask.value == true)
        #expect(sut.isQuitAlertShown == false)
        let calls = await presetProviderMock.calls
        #expect(calls.contains { call in
            if case .save(let preset, let name) = call {
                return preset.component == component && name == "default"
            }
            return false
        })
    }

    @Test
    mutating func quit_discard_resolvesProceedTrueAndDoesNotSave() async {
        let component = AudioUnitComponent.fake()
        await engineMock.setLoadResult(LoadedAudioUnit.fake(component: component))
        createSut()
        await sut.accept(action: .selected(component))
        let coordinator = quitCoordinator!

        let proceedTask = Task { await coordinator.requestQuit() }
        try? await Task.sleep(for: .milliseconds(20))

        await sut.accept(action: .quit(.discard))

        #expect(await proceedTask.value == true)
        #expect(sut.isQuitAlertShown == false)
        #expect(await presetProviderMock.calls == [])
    }

    @Test
    mutating func quit_cancel_resolvesProceedFalse() async {
        let component = AudioUnitComponent.fake()
        createSut()
        await sut.accept(action: .selected(component))
        let coordinator = quitCoordinator!

        let proceedTask = Task { await coordinator.requestQuit() }
        try? await Task.sleep(for: .milliseconds(20))

        await sut.accept(action: .quit(.cancel))

        #expect(await proceedTask.value == false)
        #expect(sut.isQuitAlertShown == false)
    }
}
