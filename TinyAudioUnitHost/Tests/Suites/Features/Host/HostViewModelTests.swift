//
//  HostViewModelTests.swift
//  TinyAudioUnitHostTests
//
//  Created by Alex Shubin on 04.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioUnitsKit
import AudioUnitsKitTestSupport
import Foundation
import PresetKit
import Testing
@testable import TinyAudioUnitHost

@MainActor
@Suite
struct HostViewModelTests {
    var libraryMock: AudioUnitComponentsLibraryMock!
    var sessionManagerMock: SessionManagerMock!
    var setupCheckerMock: SetupCheckerMock!
    var sut: HostViewModelType!

    init() {
        libraryMock = AudioUnitComponentsLibraryMock()
        sessionManagerMock = SessionManagerMock()
        setupCheckerMock = SetupCheckerMock()
    }

    mutating func createSut() {
        sut = HostViewModel(
            library: libraryMock,
            sessionManager: sessionManagerMock,
            setupChecker: setupCheckerMock
        )
    }

    private func awaitTitleChange(_ trigger: @MainActor @escaping () async -> Void) async {
        await withCheckedContinuation { continuation in
            withObservationTracking {
                _ = sut.presetTitle
            } onChange: {
                continuation.resume()
            }
            Task { @MainActor in await trigger() }
        }
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
    mutating func task_activateReturnsNil_doesNotSetContent() async {
        createSut()

        await sut.accept(action: .task)

        #expect(sut.content == .empty)
        #expect(sut.selectedComponent == nil)
        #expect(await sessionManagerMock.calls == [.activate(.stored)])
    }

    @Test
    mutating func task_activateReturnsLoaded_setsContentAndSelectedComponent() async {
        let component = AudioUnitComponent.fake(name: "Dyn")
        let loaded = LoadedAudioUnit.fake(component: component)
        sessionManagerMock = SessionManagerMock(activateResult: loaded)
        createSut()

        await sut.accept(action: .task)

        #expect(sut.selectedComponent == component)
        #expect(sut.content == .loaded(loaded))
    }

    @Test
    mutating func task_activateUnmodified_titleHasNoAsterisk() async {
        let loaded = LoadedAudioUnit.fake()
        sessionManagerMock = SessionManagerMock(activateResult: loaded, isModifiedOnLoad: false)
        createSut()

        await sut.accept(action: .task)

        #expect(sut.presetTitle == "Preset: Default")
    }

    @Test
    mutating func task_activateModified_titleHasAsterisk() async {
        let loaded = LoadedAudioUnit.fake()
        sessionManagerMock = SessionManagerMock(activateResult: loaded, isModifiedOnLoad: true)
        createSut()
        let sut = sut!

        await awaitTitleChange { await sut.accept(action: .task) }

        #expect(sut.presetTitle == "Preset: Default*")
    }

    @Test
    mutating func task_calledTwice_doesNotReloadPreset() async {
        let loaded = LoadedAudioUnit.fake()
        sessionManagerMock = SessionManagerMock(activateResult: loaded)
        createSut()

        await sut.accept(action: .task)
        await sut.accept(action: .task)

        #expect(await sessionManagerMock.calls == [.activate(.stored)])
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
    mutating func selected_activateSucceeds_setsContentToLoaded() async {
        let component = AudioUnitComponent.fake(name: "Dynamics")
        let loaded = LoadedAudioUnit.fake(component: component)
        sessionManagerMock = SessionManagerMock(activateResult: loaded)
        createSut()

        await sut.accept(action: .selected(component))

        #expect(sut.content == .loaded(loaded))
    }

    @Test
    mutating func selected_activateReturnsNil_staysInLoading() async {
        let component = AudioUnitComponent.fake(name: "Dynamics")
        createSut()

        await sut.accept(action: .selected(component))

        #expect(sut.content == .loading)
    }

    @Test
    mutating func selected_callsManagerActivateWithPickedComponent() async {
        let component = AudioUnitComponent.fake(name: "Dynamics")
        createSut()

        await sut.accept(action: .selected(component))

        #expect(await sessionManagerMock.calls == [.activate(.picked(component))])
    }

    @Test
    mutating func selected_marksTitleModified() async {
        let component = AudioUnitComponent.fake(name: "Dynamics")
        let loaded = LoadedAudioUnit.fake(component: component)
        sessionManagerMock = SessionManagerMock(activateResult: loaded)
        createSut()
        let sut = sut!

        await awaitTitleChange { await sut.accept(action: .selected(component)) }

        #expect(sut.presetTitle == "Preset: Default*")
    }

    // MARK: - saveCurrentPreset

    @Test
    mutating func saveCurrentPreset_callsManagerSaveAndClearsTitle() async {
        let component = AudioUnitComponent.fake(name: "Dyn")
        let loaded = LoadedAudioUnit.fake(component: component)
        sessionManagerMock = SessionManagerMock(activateResult: loaded)
        createSut()
        let sut = sut!

        await awaitTitleChange { await sut.accept(action: .selected(component)) }
        #expect(sut.presetTitle == "Preset: Default*")

        await awaitTitleChange { await sut.accept(action: .saveCurrentPreset) }

        #expect(sut.presetTitle == "Preset: Default")
        #expect(await sessionManagerMock.calls.contains(.save))
    }

    @Test
    mutating func saveCurrentPreset_emptyContent_doesNotCallManager() async {
        createSut()

        await sut.accept(action: .saveCurrentPreset)

        #expect(await sessionManagerMock.calls == [])
    }

    // MARK: - setup gating

    @Test
    mutating func selected_notReady_doesNotCallManager() async {
        createSut()
        let sut = sut!
        let mock = setupCheckerMock!

        await awaitUnmetChange { await mock.emit([.microphonePermission]) }
        #expect(!sut.isReady)

        await sut.accept(action: .selected(.fake()))

        #expect(await sessionManagerMock.calls == [])
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
    mutating func restorePreset_callsManagerActivateWithSavedDefault() async {
        createSut()

        await sut.accept(action: .restorePreset)

        #expect(await sessionManagerMock.calls == [.activate(.savedDefault)])
    }

    @Test
    mutating func restorePreset_activateSucceeds_setsContentAndSelectedComponent() async {
        let component = AudioUnitComponent.fake(name: "Saved")
        let loaded = LoadedAudioUnit.fake(component: component)
        sessionManagerMock = SessionManagerMock(activateResult: loaded)
        createSut()

        await sut.accept(action: .restorePreset)

        #expect(sut.selectedComponent == component)
        #expect(sut.content == .loaded(loaded))
    }

    @Test
    mutating func restorePreset_noDefault_clearsToEmpty() async {
        let component = AudioUnitComponent.fake()
        let loaded = LoadedAudioUnit.fake(component: component)
        sessionManagerMock = SessionManagerMock(activateResult: loaded)
        createSut()
        await sut.accept(action: .selected(component))
        #expect(sut.content == .loaded(loaded))
        await sessionManagerMock.setActivateResult(nil)

        await sut.accept(action: .restorePreset)

        #expect(sut.selectedComponent == nil)
        #expect(sut.content == .empty)
    }

    @Test
    mutating func restorePreset_clearsTitleModifiedFlag() async {
        createSut()
        let sut = sut!
        let mock = sessionManagerMock!
        await awaitTitleChange { await mock.emitIsModified(true) }
        #expect(sut.presetTitle == "Preset: Default*")

        await awaitTitleChange { await sut.accept(action: .restorePreset) }

        #expect(sut.presetTitle == "Preset: Default")
    }

    // MARK: - isModifiedStream proxy

    @Test
    mutating func isModifiedStream_yieldsTrue_marksTitleModified() async {
        createSut()
        let sut = sut!
        let mock = sessionManagerMock!
        #expect(sut.presetTitle == "Preset: Default")

        await awaitTitleChange { await mock.emitIsModified(true) }

        #expect(sut.presetTitle == "Preset: Default*")
    }

    @Test
    mutating func isModifiedStream_yieldsFalseAfterTrue_clearsTitle() async {
        createSut()
        let sut = sut!
        let mock = sessionManagerMock!

        await awaitTitleChange { await mock.emitIsModified(true) }
        #expect(sut.presetTitle == "Preset: Default*")

        await awaitTitleChange { await mock.emitIsModified(false) }

        #expect(sut.presetTitle == "Preset: Default")
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
