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
        case start
        case refreshSetup
        case acknowledgePresetEvent
        case loadComponent(AudioUnitComponent)
        case selectPreset(name: String)
        case saveCurrentPreset
        case restoreActivePreset
        case saveAsNewPreset(name: String)
        case renamePreset(from: String, to: String)
        case deletePreset(name: String)
    }

    private(set) var calls: [Calls] = []

    var content: HostContent = .empty
    var activeName: String?
    var presets: [String] = []
    var presetEvent: PresetEvent?

    func start() async { calls.append(.start) }
    func refreshSetup() async { calls.append(.refreshSetup) }
    func acknowledgePresetEvent() { calls.append(.acknowledgePresetEvent) }
    func loadComponent(_ component: AudioUnitComponent) async { calls.append(.loadComponent(component)) }
    func selectPreset(name: String) async { calls.append(.selectPreset(name: name)) }
    func saveCurrentPreset() { calls.append(.saveCurrentPreset) }
    func restoreActivePreset() async { calls.append(.restoreActivePreset) }
    func saveAsNewPreset(name: String) { calls.append(.saveAsNewPreset(name: name)) }
    func renamePreset(from: String, to: String) { calls.append(.renamePreset(from: from, to: to)) }
    func deletePreset(name: String) { calls.append(.deletePreset(name: name)) }
}
