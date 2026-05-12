//
//  SessionManagerTests.swift
//  TinyAudioUnitHostTests
//
//  Created by Alex Shubin on 09.05.26.
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

@Suite
struct SessionManagerTests {
    var presetProviderMock: PresetProviderMock!
    var engineMock: EngineMock!
    var sut: SessionManagerType!

    init() {
        presetProviderMock = PresetProviderMock()
        engineMock = EngineMock()
    }

    mutating func createSut() {
        sut = SessionManager(presetProvider: presetProviderMock, engine: engineMock)
    }

    // MARK: - activate(.stored)

    @Test
    mutating func activateStored_noDefault_returnsNil() async {
        createSut()

        #expect(await sut.activate(.stored) == nil)
    }

    @Test
    mutating func activateStored_default_engineLoadsIt() async {
        let component = AudioUnitComponent.fake()
        let preset = Preset(component: component, state: Data([0x01]))
        let loaded = LoadedAudioUnit.fake(component: component)
        presetProviderMock = PresetProviderMock(defaultPreset: preset)
        engineMock = EngineMock(loadResult: loaded)
        createSut()

        let result = await sut.activate(.stored)

        #expect(result == loaded)
        #expect(await engineMock.calls == [.load(component, Data([0x01]))])
    }

    @Test
    mutating func activateStored_engineLoadFails_returnsNil() async {
        let component = AudioUnitComponent.fake()
        presetProviderMock = PresetProviderMock(defaultPreset: Preset(component: component, state: Data()))
        createSut()  // engineMock.loadResult is nil

        #expect(await sut.activate(.stored) == nil)
    }

    // MARK: - activate(.picked)

    @Test
    mutating func activatePicked_engineLoadsWithNilState_returnsLoaded() async {
        let component = AudioUnitComponent.fake()
        let loaded = LoadedAudioUnit.fake(component: component)
        engineMock = EngineMock(loadResult: loaded)
        createSut()

        let result = await sut.activate(.picked(component))

        #expect(result == loaded)
        #expect(await engineMock.calls == [.load(component, nil)])
    }

    @Test
    mutating func activatePicked_engineLoadFails_returnsNil() async {
        createSut()  // engineMock.loadResult is nil

        #expect(await sut.activate(.picked(.fake())) == nil)
    }

    // MARK: - save

    @Test
    mutating func save_noCurrent_doesNothing() async {
        createSut()

        await sut.save()

        #expect(await presetProviderMock.calls == [])
    }

    @Test
    mutating func save_writesDefaultThroughProvider() async {
        let component = AudioUnitComponent.fake()
        let auMock = AUAudioUnitMock(fullState: Data([0xBE, 0xEF]))
        let loaded = LoadedAudioUnit.fake(component: component, audioUnit: auMock)
        engineMock = EngineMock(loadResult: loaded)
        createSut()
        _ = await sut.activate(.picked(component))

        await sut.save()

        let expected = Preset(component: component, state: Data([0xBE, 0xEF]))
        #expect(await presetProviderMock.calls == [.saveDefault(expected)])
    }
}
