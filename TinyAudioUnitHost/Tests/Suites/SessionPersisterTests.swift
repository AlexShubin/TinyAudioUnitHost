//
//  SessionPersisterTests.swift
//  TinyAudioUnitHostTests
//
//  Created by Alex Shubin on 07.05.26.
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
struct SessionPersisterTests {
    var presetProviderMock: PresetProviderMock!
    var sut: SessionPersisterType!

    init() {
        presetProviderMock = PresetProviderMock()
    }

    mutating func createSut() {
        sut = SessionPersister(presetProvider: presetProviderMock)
    }

    @Test
    mutating func persistSession_noCurrent_doesNotCallProvider() async {
        createSut()

        await sut.persistSession()

        #expect(await presetProviderMock.calls == [])
    }

    @Test
    mutating func persistSession_currentSet_savesPresetToSessionSlot() async {
        let component = AudioUnitComponent.fake()
        let auMock = AUAudioUnitMock(fullState: Data([0xAB, 0xCD]))
        let loaded = LoadedAudioUnit.fake(component: component, audioUnit: auMock)
        createSut()
        await sut.setCurrent(loaded)

        await sut.persistSession()

        let calls = await presetProviderMock.calls
        #expect(calls == [.save(Preset(component: component, state: Data([0xAB, 0xCD])), slot: .session)])
    }

    @Test
    mutating func persistSession_fullStateNil_doesNotCallProvider() async {
        let auMock = AUAudioUnitMock(fullState: nil)
        let loaded = LoadedAudioUnit.fake(audioUnit: auMock)
        createSut()
        await sut.setCurrent(loaded)

        await sut.persistSession()

        #expect(await presetProviderMock.calls == [])
    }

    @Test
    mutating func setCurrent_replacesPreviousCurrent() async {
        let firstAU = AUAudioUnitMock(fullState: Data([0x11]))
        let secondAU = AUAudioUnitMock(fullState: Data([0x22]))
        let firstComponent = AudioUnitComponent.fake(name: "First")
        let secondComponent = AudioUnitComponent.fake(name: "Second")
        createSut()
        await sut.setCurrent(LoadedAudioUnit.fake(component: firstComponent, audioUnit: firstAU))

        await sut.setCurrent(LoadedAudioUnit.fake(component: secondComponent, audioUnit: secondAU))
        await sut.persistSession()

        let calls = await presetProviderMock.calls
        #expect(calls == [.save(Preset(component: secondComponent, state: Data([0x22])), slot: .session)])
    }

    @Test
    mutating func setCurrent_nil_clearsCurrent() async {
        let auMock = AUAudioUnitMock(fullState: Data([0xFF]))
        createSut()
        await sut.setCurrent(LoadedAudioUnit.fake(audioUnit: auMock))

        await sut.setCurrent(nil)
        await sut.persistSession()

        #expect(await presetProviderMock.calls == [])
    }
}
