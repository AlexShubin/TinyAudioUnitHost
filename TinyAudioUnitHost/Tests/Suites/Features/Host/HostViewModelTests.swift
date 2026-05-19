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
import PurchasesKit
import PurchasesKitTestSupport
import Testing
@testable import TinyAudioUnitHost

@MainActor
@Suite
struct HostViewModelTests {
    var libraryMock: AudioUnitComponentsLibraryMock!
    var engineMock: EngineMock!
    var presetProviderMock: PresetProviderMock!
    var presetNameValidatorMock: PresetNameValidatorMock!
    var setupCheckerMock: SetupCheckerMock!
    var purchasesServiceMock: PurchasesServiceMock!
    var sut: HostViewModelType!

    init() {
        libraryMock = AudioUnitComponentsLibraryMock()
        engineMock = EngineMock()
        presetProviderMock = PresetProviderMock()
        presetNameValidatorMock = PresetNameValidatorMock()
        setupCheckerMock = SetupCheckerMock()
        purchasesServiceMock = PurchasesServiceMock()
    }

    mutating func createSut() {
        sut = HostViewModel(
            library: libraryMock,
            engine: engineMock,
            presetProvider: presetProviderMock,
            setupChecker: setupCheckerMock,
            presetNameValidator: presetNameValidatorMock,
            purchasesService: purchasesServiceMock
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
        libraryMock.components = [
            .fake(name: "Reverb", manufacturer: "Zoom"),
            .fake(name: "Dynamics", manufacturer: "Apple"),
            .fake(name: "Compressor", manufacturer: "Korn"),
        ]
        createSut()

        await sut.accept(action: .task)

        #expect(sut.groups.map(\.manufacturer) == ["Apple", "Korn", "Zoom"])
    }

    @Test
    mutating func task_emptyLibrary_emptyGroups() async {
        createSut()

        await sut.accept(action: .task)

        #expect(sut.groups == [])
    }

    @Test
    mutating func task_noActiveAndNoPresets_setsContentEmpty() async {
        createSut()

        await sut.accept(action: .task)

        #expect(sut.content == .empty)
        #expect(sut.activeName == nil)
        #expect(await engineMock.calls == [])
    }

    @Test
    mutating func task_storedActiveValid_loadsIntoEngine() async {
        let component = AudioUnitComponent.fake(componentDescription: .fakeEffect)
        let loaded = LoadedAudioUnit.fake(component: component)
        presetProviderMock = PresetProviderMock(
            presets: ["foo": Preset(name: "foo", component: component, state: Data([0x01]))],
            activeName: "foo"
        )
        engineMock = EngineMock(loadResult: .success(loaded))
        createSut()

        await sut.accept(action: .task)

        #expect(sut.activeName == "foo")
        #expect(sut.content == .loaded(loaded))
        #expect(await engineMock.calls == [.load(component, Data([0x01]))])
    }

    @Test
    mutating func task_storedActiveStale_clearsActiveAndShowsEmpty() async {
        presetProviderMock.currentActiveName = "ghost"
        createSut()

        await sut.accept(action: .task)

        #expect(sut.activeName == nil)
        #expect(sut.content == .empty)
        #expect(presetProviderMock.currentActiveName == nil)
        #expect(presetProviderMock.calls.contains(.setActive(nil)))
    }

    @Test
    mutating func task_presetsExistButNoActive_staysInNotSelected() async {
        let component = AudioUnitComponent.fake(componentDescription: .fakeEffect)
        presetProviderMock = PresetProviderMock(
            presets: ["foo": Preset(name: "foo", component: component, state: Data())]
        )
        createSut()

        await sut.accept(action: .task)

        #expect(sut.activeName == nil)
        #expect(sut.content == .empty)
        #expect(await engineMock.calls == [])
    }

    @Test
    mutating func task_calledTwice_doesNotReloadActivePreset() async {
        let component = AudioUnitComponent.fake(componentDescription: .fakeEffect)
        let loaded = LoadedAudioUnit.fake(component: component)
        presetProviderMock = PresetProviderMock(
            presets: ["foo": Preset(name: "foo", component: component, state: Data())],
            activeName: "foo"
        )
        engineMock = EngineMock(loadResult: .success(loaded))
        createSut()

        await sut.accept(action: .task)
        await sut.accept(action: .task)

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
    mutating func selected_withActiveName_doesNotWriteBack() async {
        let original = Preset.fake(name: "active", state: Data([0x01]))
        let differentComponent = AudioUnitComponent.fake(componentDescription: .fakeEffect)
        let auMock = AUAudioUnitMock(fullState: Data([0xBE, 0xEF]))
        let loaded = LoadedAudioUnit.fake(component: differentComponent, audioUnit: auMock)
        engineMock = EngineMock(loadResult: .success(loaded))
        presetProviderMock = PresetProviderMock(
            presets: ["active": original],
            activeName: "active"
        )
        createSut()
        await sut.accept(action: .task)

        await sut.accept(action: .selected(differentComponent))

        // Picking an AU only loads it into the engine; the active preset's file
        // stays untouched until the user explicitly saves.
        #expect(presetProviderMock.storedPresets["active"] == original)
    }

    @Test
    mutating func selected_withoutActiveName_doesNotWriteBack() async {
        let component = AudioUnitComponent.fake(componentDescription: .fakeEffect)
        let auMock = AUAudioUnitMock(fullState: Data([0xBE, 0xEF]))
        let loaded = LoadedAudioUnit.fake(component: component, audioUnit: auMock)
        engineMock = EngineMock(loadResult: .success(loaded))
        createSut()

        await sut.accept(action: .selected(component))

        #expect(presetProviderMock.storedPresets.isEmpty)
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

    // MARK: - saveCurrentPreset

    @Test
    mutating func saveCurrentPreset_loadedAndActive_writesAndSetsFeedback() async {
        let component = AudioUnitComponent.fake(componentDescription: .fakeEffect)
        let auMock = AUAudioUnitMock(fullState: Data([0xBE, 0xEF]))
        let loaded = LoadedAudioUnit.fake(component: component, audioUnit: auMock)
        engineMock = EngineMock(loadResult: .success(loaded))
        presetProviderMock = PresetProviderMock(
            presets: ["active": Preset(name: "active", component: component, state: Data())],
            activeName: "active"
        )
        createSut()
        await sut.accept(action: .task)

        await sut.accept(action: .saveCurrentPreset)

        let expected = Preset(name: "active", component: component, state: Data([0xBE, 0xEF]))
        #expect(presetProviderMock.storedPresets["active"] == expected)
        #expect(sut.feedback?.kind == .saved)
    }

    @Test
    mutating func saveCurrentPreset_emptyContent_doesNothing() async {
        presetProviderMock = PresetProviderMock(activeName: "active")
        createSut()

        await sut.accept(action: .saveCurrentPreset)

        #expect(presetProviderMock.storedPresets.isEmpty)
        #expect(sut.feedback == nil)
    }

    @Test
    mutating func saveCurrentPreset_loadedButNoActive_doesNothing() async {
        let component = AudioUnitComponent.fake()
        let loaded = LoadedAudioUnit.fake(component: component)
        engineMock = EngineMock(loadResult: .success(loaded))
        createSut()
        await sut.accept(action: .selected(component))

        await sut.accept(action: .saveCurrentPreset)

        #expect(presetProviderMock.storedPresets.isEmpty)
        #expect(sut.feedback == nil)
    }

    // MARK: - restorePreset

    @Test
    mutating func restorePreset_activeAndLoadable_reloadsAndShowsFeedback() async {
        let component = AudioUnitComponent.fake(componentDescription: .fakeEffect)
        let loaded = LoadedAudioUnit.fake(component: component)
        presetProviderMock = PresetProviderMock(
            presets: ["saved": Preset(name: "saved", component: component, state: Data([0x01]))],
            activeName: "saved"
        )
        engineMock = EngineMock(loadResult: .success(loaded))
        createSut()
        await sut.accept(action: .task)
        #expect(sut.activeName == "saved")

        await sut.accept(action: .restorePreset)

        #expect(sut.content == .loaded(loaded))
        #expect(sut.feedback?.kind == .restored)
    }

    @Test
    mutating func restorePreset_noActive_isNoOp() async {
        createSut()

        await sut.accept(action: .restorePreset)

        #expect(await engineMock.calls == [])
        #expect(sut.feedback == nil)
    }

    @Test
    mutating func restorePreset_engineFails_doesNotSetFeedback() async {
        let component = AudioUnitComponent.fake(componentDescription: .fakeEffect)
        presetProviderMock = PresetProviderMock(
            presets: ["saved": Preset(name: "saved", component: component, state: Data())],
            activeName: "saved"
        )
        // engineMock defaults to .failure
        createSut()
        await sut.accept(action: .task)
        // After task, content is .failed (engine load failed).
        // Restore should attempt load again and fail.

        await sut.accept(action: .restorePreset)

        #expect(sut.feedback == nil)
    }

    // MARK: - selectedPreset

    @Test
    mutating func selectedPreset_setsActiveAndCallsSetActive() async {
        let component = AudioUnitComponent.fake(componentDescription: .fakeEffect)
        let loaded = LoadedAudioUnit.fake(component: component)
        presetProviderMock = PresetProviderMock(
            presets: ["foo": Preset(name: "foo", component: component, state: Data())]
        )
        engineMock = EngineMock(loadResult: .success(loaded))
        createSut()

        await sut.accept(action: .presetsSidebarAction(.selected(name: "foo")))

        #expect(sut.activeName == "foo")
        #expect(presetProviderMock.currentActiveName == "foo")
    }

    @Test
    mutating func selectedPreset_validName_loadsPresetIntoEngine() async {
        let component = AudioUnitComponent.fake(componentDescription: .fakeEffect)
        let loaded = LoadedAudioUnit.fake(component: component)
        presetProviderMock = PresetProviderMock(
            presets: ["foo": Preset(name: "foo", component: component, state: Data([0x07]))]
        )
        engineMock = EngineMock(loadResult: .success(loaded))
        createSut()

        await sut.accept(action: .presetsSidebarAction(.selected(name: "foo")))

        #expect(sut.content == .loaded(loaded))
        #expect(await engineMock.calls == [.load(component, Data([0x07]))])
    }

    @Test
    mutating func selectedPreset_missingPreset_setsContentToEmpty() async {
        createSut()

        await sut.accept(action: .presetsSidebarAction(.selected(name: "ghost")))

        #expect(sut.content == .empty)
        #expect(sut.selectedComponent == nil)
        #expect(await engineMock.calls == [])
    }

    @Test
    mutating func selectedPreset_notReady_doesNotLoadEngine() async {
        createSut()
        let sut = sut!
        let mock = setupCheckerMock!
        await awaitUnmetChange { await mock.emit([.microphonePermission]) }

        await sut.accept(action: .presetsSidebarAction(.selected(name: "foo")))

        #expect(await engineMock.calls == [])
    }

    // MARK: - newPresetTapped

    @Test
    mutating func newPresetTapped_opensEmptyDialog() async {
        createSut()

        await sut.accept(action: .newPresetTapped)

        #expect(sut.newPresetDialog == NewPresetDialogState(name: "", error: nil))
    }

    // MARK: - newPresetDialogAction

    @Test
    mutating func nameChanged_dialogClosed_isNoOp() async {
        createSut()

        await sut.accept(action: .newPresetDialogAction(.nameChanged("foo")))

        #expect(sut.newPresetDialog == nil)
    }

    @Test
    mutating func nameChanged_validName_updatesNameAndClearsError() async {
        createSut()
        await sut.accept(action: .newPresetTapped)

        await sut.accept(action: .newPresetDialogAction(.nameChanged("MyPreset")))

        #expect(sut.newPresetDialog == NewPresetDialogState(name: "MyPreset", error: nil))
    }

    @Test
    mutating func nameChanged_invalidName_setsError() async {
        presetNameValidatorMock.result = .duplicate
        createSut()
        await sut.accept(action: .newPresetTapped)

        await sut.accept(action: .newPresetDialogAction(.nameChanged("dupe")))

        #expect(sut.newPresetDialog == NewPresetDialogState(name: "dupe", error: .duplicate))
    }

    @Test
    mutating func nameChanged_callsValidatorWithSaveAsMode() async {
        createSut()
        await sut.accept(action: .newPresetTapped)

        await sut.accept(action: .newPresetDialogAction(.nameChanged("anything")))

        #expect(presetNameValidatorMock.calls == [.validate(name: "anything", mode: .saveAs)])
    }

    @Test
    mutating func cancel_closesDialog() async {
        createSut()
        await sut.accept(action: .newPresetTapped)

        await sut.accept(action: .newPresetDialogAction(.cancel))

        #expect(sut.newPresetDialog == nil)
    }

    @Test
    mutating func commit_dialogClosed_isNoOp() async {
        createSut()

        await sut.accept(action: .newPresetDialogAction(.commit))

        #expect(presetProviderMock.calls.isEmpty)
    }

    @Test
    mutating func commit_emptyContent_isNoOp() async {
        createSut()
        await sut.accept(action: .newPresetTapped)
        await sut.accept(action: .newPresetDialogAction(.nameChanged("foo")))

        await sut.accept(action: .newPresetDialogAction(.commit))

        #expect(presetProviderMock.storedPresets.isEmpty)
    }

    @Test
    mutating func commit_success_setsActiveDismissesAndShowsFeedback() async {
        let component = AudioUnitComponent.fake(componentDescription: .fakeEffect)
        let auMock = AUAudioUnitMock(fullState: Data([0xBE, 0xEF]))
        let loaded = LoadedAudioUnit.fake(component: component, audioUnit: auMock)
        engineMock = EngineMock(loadResult: .success(loaded))
        createSut()
        await sut.accept(action: .selected(component))
        await sut.accept(action: .newPresetTapped)
        await sut.accept(action: .newPresetDialogAction(.nameChanged("MyNew")))

        await sut.accept(action: .newPresetDialogAction(.commit))

        #expect(sut.activeName == "MyNew")
        #expect(sut.newPresetDialog == nil)
        #expect(sut.feedback?.kind == .saved)
        #expect(presetProviderMock.currentActiveName == "MyNew")
    }

    @Test
    mutating func commit_failure_keepsDialogOpenWithError() async {
        let component = AudioUnitComponent.fake(componentDescription: .fakeEffect)
        let auMock = AUAudioUnitMock(fullState: Data())
        let loaded = LoadedAudioUnit.fake(component: component, audioUnit: auMock)
        engineMock = EngineMock(loadResult: .success(loaded))
        presetProviderMock.saveAsResult = .failure(.duplicate)
        createSut()
        await sut.accept(action: .selected(component))
        await sut.accept(action: .newPresetTapped)
        await sut.accept(action: .newPresetDialogAction(.nameChanged("dupe")))

        await sut.accept(action: .newPresetDialogAction(.commit))

        #expect(sut.newPresetDialog == NewPresetDialogState(name: "dupe", error: .duplicate))
        #expect(sut.activeName == nil)
        #expect(sut.feedback == nil)
    }

    // MARK: - renamePreset

    @Test
    mutating func renamePreset_success_refreshesPresetsAndActive() async {
        let component = AudioUnitComponent.fake(componentDescription: .fakeEffect)
        presetProviderMock = PresetProviderMock(
            presets: ["old": Preset(name: "old", component: component, state: Data())],
            activeName: "old"
        )
        createSut()

        await sut.accept(action: .presetsSidebarAction(.rename(from: "old", to: "new")))

        #expect(sut.activeName == "new")
        #expect(sut.presets.contains { $0.name == "new" })
    }

    // MARK: - deletePreset

    @Test
    mutating func deletePreset_callsProviderAndRefreshes() async {
        let component = AudioUnitComponent.fake(componentDescription: .fakeEffect)
        presetProviderMock = PresetProviderMock(
            presets: ["target": Preset(name: "target", component: component, state: Data())]
        )
        createSut()

        await sut.accept(action: .presetsSidebarAction(.delete(name: "target")))

        #expect(sut.presets.isEmpty)
        #expect(presetProviderMock.calls.contains(.delete(name: "target")))
    }

    @Test
    mutating func deletePreset_activeMatched_activeBecomesNil() async {
        let component = AudioUnitComponent.fake(componentDescription: .fakeEffect)
        presetProviderMock = PresetProviderMock(
            presets: ["target": Preset(name: "target", component: component, state: Data())],
            activeName: "target"
        )
        createSut()

        await sut.accept(action: .presetsSidebarAction(.delete(name: "target")))

        #expect(sut.activeName == nil)
    }

    // MARK: - feedbackToastAction

    @Test
    mutating func feedbackToastAction_timedOut_clearsFeedback() async {
        let component = AudioUnitComponent.fake(componentDescription: .fakeEffect)
        let loaded = LoadedAudioUnit.fake(component: component)
        engineMock = EngineMock(loadResult: .success(loaded))
        presetProviderMock = PresetProviderMock(
            presets: ["active": Preset(name: "active", component: component, state: Data())],
            activeName: "active"
        )
        createSut()
        await sut.accept(action: .task)
        await sut.accept(action: .saveCurrentPreset)
        #expect(sut.feedback != nil)

        await sut.accept(action: .feedbackToastAction(.timedOut))

        #expect(sut.feedback == nil)
    }

    // MARK: - setup gating

    @Test
    mutating func setupChecker_yields_updatesUnmetRequirements() async {
        createSut()
        let sut = sut!
        let mock = setupCheckerMock!

        await awaitUnmetChange { await mock.emit([.outputDevice]) }

        #expect(sut.unmetRequirements == [.outputDevice])
        #expect(!sut.isReady)
    }

    // MARK: - free-tier cap on presets

    @Test
    mutating func presets_freeUserWithMoreThanTwo_seesOnlyFirstTwo() async {
        let component = AudioUnitComponent.fake(componentDescription: .fakeEffect)
        presetProviderMock = PresetProviderMock(presets: [
            "alpha": Preset(name: "alpha", component: component, state: Data()),
            "beta": Preset(name: "beta", component: component, state: Data()),
            "gamma": Preset(name: "gamma", component: component, state: Data()),
        ])
        purchasesServiceMock = PurchasesServiceMock(isPro: false)
        createSut()

        await sut.accept(action: .task)

        #expect(sut.presets.map(\.name) == ["alpha", "beta"])
    }

    @Test
    mutating func presets_proUserWithMoreThanTwo_seesAll() async {
        let component = AudioUnitComponent.fake(componentDescription: .fakeEffect)
        presetProviderMock = PresetProviderMock(presets: [
            "alpha": Preset(name: "alpha", component: component, state: Data()),
            "beta": Preset(name: "beta", component: component, state: Data()),
            "gamma": Preset(name: "gamma", component: component, state: Data()),
        ])
        purchasesServiceMock = PurchasesServiceMock(isPro: true)
        createSut()

        await sut.accept(action: .task)

        #expect(sut.presets.map(\.name) == ["alpha", "beta", "gamma"])
    }

    // MARK: - newPresetTapped gate

    @Test
    mutating func newPresetTapped_freeUserAtCap_setsOpenProWindowRequest() async {
        let component = AudioUnitComponent.fake(componentDescription: .fakeEffect)
        presetProviderMock = PresetProviderMock(presets: [
            "alpha": Preset(name: "alpha", component: component, state: Data()),
            "beta": Preset(name: "beta", component: component, state: Data()),
        ])
        purchasesServiceMock = PurchasesServiceMock(isPro: false)
        createSut()
        await sut.accept(action: .task)

        await sut.accept(action: .newPresetTapped)

        #expect(sut.openProWindowRequest != nil)
        #expect(sut.newPresetDialog == nil)
    }

    @Test
    mutating func newPresetTapped_freeUserBelowCap_opensDialog() async {
        let component = AudioUnitComponent.fake(componentDescription: .fakeEffect)
        presetProviderMock = PresetProviderMock(presets: [
            "alpha": Preset(name: "alpha", component: component, state: Data()),
        ])
        purchasesServiceMock = PurchasesServiceMock(isPro: false)
        createSut()

        await sut.accept(action: .newPresetTapped)

        #expect(sut.newPresetDialog != nil)
        #expect(sut.openProWindowRequest == nil)
    }

    @Test
    mutating func newPresetTapped_proUserAboveCap_opensDialog() async {
        let component = AudioUnitComponent.fake(componentDescription: .fakeEffect)
        presetProviderMock = PresetProviderMock(presets: [
            "alpha": Preset(name: "alpha", component: component, state: Data()),
            "beta": Preset(name: "beta", component: component, state: Data()),
            "gamma": Preset(name: "gamma", component: component, state: Data()),
        ])
        purchasesServiceMock = PurchasesServiceMock(isPro: true)
        createSut()

        await sut.accept(action: .newPresetTapped)

        #expect(sut.newPresetDialog != nil)
        #expect(sut.openProWindowRequest == nil)
    }

    @Test
    mutating func newPresetTapped_freeUserAtCap_repeatedTap_changesRequestToken() async {
        let component = AudioUnitComponent.fake(componentDescription: .fakeEffect)
        presetProviderMock = PresetProviderMock(presets: [
            "alpha": Preset(name: "alpha", component: component, state: Data()),
            "beta": Preset(name: "beta", component: component, state: Data()),
        ])
        purchasesServiceMock = PurchasesServiceMock(isPro: false)
        createSut()
        await sut.accept(action: .task)

        await sut.accept(action: .newPresetTapped)
        let first = sut.openProWindowRequest
        await sut.accept(action: .newPresetTapped)
        let second = sut.openProWindowRequest

        #expect(first != nil)
        #expect(second != nil)
        #expect(first != second)
    }
}
