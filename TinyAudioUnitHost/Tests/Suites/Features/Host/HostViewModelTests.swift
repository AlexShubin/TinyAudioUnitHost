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
    var presetManagerMock: PresetManagerMock!
    var sut: HostViewModelType!

    init() {
        engineMock = EngineMock()
        libraryMock = AudioUnitComponentsLibraryMock()
        presetManagerMock = PresetManagerMock()
    }

    mutating func createSut() {
        sut = HostViewModel(
            engine: engineMock,
            library: libraryMock,
            presetManager: presetManagerMock
        )
    }

    /// Triggers a parameter change on the AU and awaits the VM's reactive update
    /// to `presetTitle` via Observation tracking. Modifications use unbounded
    /// buffering, so the trigger may fire before or after the listener task
    /// reaches its for-await suspension — either way the value lands.
    private func triggerAndAwaitTitleChange(_ auMock: AUAudioUnitMock) async {
        await withCheckedContinuation { continuation in
            withObservationTracking {
                _ = sut.presetTitle
            } onChange: {
                continuation.resume()
            }
            auMock.triggerOnChange()
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
    mutating func task_noActivePreset_doesNotCallEngine() async {
        createSut()

        await sut.accept(action: .task)

        #expect(await engineMock.calls == [])
    }

    @Test
    mutating func task_activePresetExists_loadsThroughEngineWithComponentAndState() async {
        let component = AudioUnitComponent.fake()
        let state = Data([0xDE, 0xAD])
        presetManagerMock = PresetManagerMock(activePreset: ActivePreset(
            preset: Preset(component: component, state: state),
            isModified: false
        ))
        await engineMock.setLoadResult(LoadedAudioUnit.fake(component: component))
        createSut()

        await sut.accept(action: .task)

        #expect(await engineMock.calls == [.load(component, state)])
    }

    @Test
    mutating func task_activePresetExists_setsLoadedContentAndSelectedComponent() async {
        let component = AudioUnitComponent.fake(name: "Dyn")
        let preset = Preset(component: component, state: Data([0x01]))
        presetManagerMock = PresetManagerMock(activePreset: ActivePreset(preset: preset, isModified: false))
        let loaded = LoadedAudioUnit.fake(component: component)
        await engineMock.setLoadResult(loaded)
        createSut()

        await sut.accept(action: .task)

        #expect(sut.selectedComponent == component)
        #expect(sut.content == .loaded(loaded))
    }

    @Test
    mutating func task_activePresetUnmodified_doesNotMarkTitleModified() async {
        let component = AudioUnitComponent.fake()
        let preset = Preset(component: component, state: Data())
        presetManagerMock = PresetManagerMock(activePreset: ActivePreset(preset: preset, isModified: false))
        await engineMock.setLoadResult(LoadedAudioUnit.fake(component: component))
        createSut()

        await sut.accept(action: .task)

        #expect(sut.presetTitle == "Preset: Default")
    }

    @Test
    mutating func task_activePresetModified_marksTitleModified() async {
        let component = AudioUnitComponent.fake()
        let preset = Preset(component: component, state: Data([0x02]))
        presetManagerMock = PresetManagerMock(activePreset: ActivePreset(preset: preset, isModified: true))
        await engineMock.setLoadResult(LoadedAudioUnit.fake(component: component))
        createSut()

        await sut.accept(action: .task)

        #expect(sut.presetTitle == "Preset: Default*")
    }

    @Test
    mutating func task_loadedAU_publishesToManager() async {
        let component = AudioUnitComponent.fake()
        let preset = Preset(component: component, state: Data())
        presetManagerMock = PresetManagerMock(activePreset: ActivePreset(preset: preset, isModified: false))
        let loaded = LoadedAudioUnit.fake(component: component)
        await engineMock.setLoadResult(loaded)
        createSut()

        await sut.accept(action: .task)

        let calls = await presetManagerMock.calls
        #expect(calls.contains(.setCurrent(loaded)))
    }

    @Test
    mutating func task_calledTwice_doesNotReloadPreset() async {
        let component = AudioUnitComponent.fake()
        let preset = Preset(component: component, state: Data())
        presetManagerMock = PresetManagerMock(activePreset: ActivePreset(preset: preset, isModified: false))
        await engineMock.setLoadResult(LoadedAudioUnit.fake(component: component))
        createSut()

        await sut.accept(action: .task)
        let callsAfterFirst = await engineMock.calls

        await sut.accept(action: .task)

        #expect(await engineMock.calls == callsAfterFirst)
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

    @Test
    mutating func selected_loadedAU_publishesToManager() async {
        let component = AudioUnitComponent.fake(name: "Dynamics")
        let loaded = LoadedAudioUnit.fake(component: component)
        await engineMock.setLoadResult(loaded)
        createSut()

        await sut.accept(action: .selected(component))

        let calls = await presetManagerMock.calls
        #expect(calls.contains(.setCurrent(loaded)))
    }

    // MARK: - saveCurrentPreset

    @Test
    mutating func saveCurrentPreset_callsManagerSaveAndClearsTitle() async {
        let component = AudioUnitComponent.fake(name: "Dyn")
        let loaded = LoadedAudioUnit.fake(component: component)
        await engineMock.setLoadResult(loaded)
        createSut()
        await sut.accept(action: .selected(component))
        #expect(sut.presetTitle == "Preset: Default*")

        await sut.accept(action: .saveCurrentPreset)

        #expect(sut.presetTitle == "Preset: Default")
        let calls = await presetManagerMock.calls
        #expect(calls.contains(.save))
    }

    @Test
    mutating func task_paramChange_marksTitleModified() async {
        let component = AudioUnitComponent.fake()
        let preset = Preset(component: component, state: Data())
        presetManagerMock = PresetManagerMock(activePreset: ActivePreset(preset: preset, isModified: false))
        let auMock = AUAudioUnitMock()
        await engineMock.setLoadResult(LoadedAudioUnit.fake(component: component, audioUnit: auMock))
        createSut()

        await sut.accept(action: .task)
        #expect(sut.presetTitle == "Preset: Default")

        await triggerAndAwaitTitleChange(auMock)

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

        await triggerAndAwaitTitleChange(auMock)

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
}
