//
//  PresetsObserverTests.swift
//  TinyAudioUnitHostTests
//
//  Created by Alex Shubin on 13.11.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioUnitsKit
import AudioUnitsKitTestSupport
import ChannelStripKit
import ChannelStripKitTestSupport
import Foundation
import PresetKit
import PresetKitTestSupport
import Testing
@testable import TinyAudioUnitHost

@MainActor
@Suite
struct PresetsObserverTests {
    var presetsSpy: PresetsModelSpy!
    var channelStripSpy: ChannelStripModelSpy!
    var sut: PresetsObserver!

    init() {
        presetsSpy = PresetsModelSpy()
        channelStripSpy = ChannelStripModelSpy()
    }

    mutating func createSut() {
        sut = PresetsObserver(presets: presetsSpy, channelStrip: channelStripSpy)
    }

    // MARK: - init

    @Test
    mutating func init_becomesModelDelegate() {
        createSut()

        #expect(presetsSpy.delegate === sut)
    }

    // MARK: - presetsDidActivate

    @Test
    mutating func activate_replacesChannelStripChain() async {
        let installed = AudioUnitComponent.fake(name: "Installed")
        let missing = AudioUnitComponent.fake(id: .init(type: 1, subType: 2, manufacturer: 3), name: "Missing")
        createSut()

        await presetsSpy.delegate?.presetsDidActivate(preset: .fake(slots: [
            .fake(component: installed, state: Data([0x01]), isBypassed: true),
            nil,
            .fake(component: missing, state: Data([0x02]), isInstalled: false),
        ]))

        #expect(channelStripSpy.calls == [.replace(with: [
            .fake(component: installed, state: Data([0x01]), isBypassed: true),
            nil,
            .fake(component: missing, state: Data([0x02]), isInstalled: false),
        ])])
    }

    @Test
    mutating func activate_emptyPreset_clearsChannelStrip() async {
        createSut()

        await presetsSpy.delegate?.presetsDidActivate(preset: .fake(slots: []))

        #expect(channelStripSpy.calls == [.replace(with: [])])
    }
}
