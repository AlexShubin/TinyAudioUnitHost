//
//  SessionModelSpy.swift
//  TinyAudioUnitHostTests
//
//  Created by Alex Shubin on 21.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioUnitsKit
import Foundation
import Observation
import PresetKit
@testable import TinyAudioUnitHost

@MainActor @Observable
final class SessionModelSpy: SessionModelType {
    enum Calls: Equatable, Sendable {
        case load
        case acknowledgePresetEvent
        case loadComponent(AudioUnitComponent, at: Int)
        case unload(at: Int)
        case setBypassed(Bool, at: Int)
        case select(Int)
        case selectPreset(name: String)
        case saveCurrentPreset
        case restoreActivePreset
        case saveAsNewPreset(name: String)
        case renamePreset(from: String, to: String)
        case deletePreset(name: String)
    }

    private(set) var calls: [Calls] = []

    var slots: [PluginSlotContent] = []
    var selectedIndex = 0
    var isBusy = false
    var canSavePreset = false
    var activePresetName: String?
    var presets: [String] = []
    var presetEvent: PresetEvent?

    func load() async { calls.append(.load) }
    func acknowledgePresetEvent() { calls.append(.acknowledgePresetEvent) }
    func load(_ component: AudioUnitComponent, at index: Int) async { calls.append(.loadComponent(component, at: index)) }
    func unload(at index: Int) async { calls.append(.unload(at: index)) }
    func setBypassed(_ isBypassed: Bool, at index: Int) { calls.append(.setBypassed(isBypassed, at: index)) }
    func select(_ index: Int) { calls.append(.select(index)) }
    func selectPreset(name: String) async { calls.append(.selectPreset(name: name)) }
    func saveCurrentPreset() { calls.append(.saveCurrentPreset) }
    func restoreActivePreset() async { calls.append(.restoreActivePreset) }
    func saveAsNewPreset(name: String) { calls.append(.saveAsNewPreset(name: name)) }
    func renamePreset(from: String, to: String) { calls.append(.renamePreset(from: from, to: to)) }
    func deletePreset(name: String) { calls.append(.deletePreset(name: name)) }
}
