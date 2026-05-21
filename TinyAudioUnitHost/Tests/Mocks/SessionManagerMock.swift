//
//  SessionManagerMock.swift
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
final class SessionManagerMock: SessionManagerType {
    enum Calls: Equatable, Sendable {
        case start
        case loadComponent(AudioUnitComponent)
        case selectPreset(name: String)
        case saveCurrentPreset
        case restoreActivePreset
        case saveAsNewPreset(name: String)
        case renamePreset(from: String, to: String)
        case deletePreset(name: String)
    }

    private(set) var content: HostContent = .empty
    private(set) var activeName: String?
    private(set) var presets: [Preset] = []
    private(set) var calls: [Calls] = []

    init(
        content: HostContent = .empty,
        activeName: String? = nil,
        presets: [Preset] = []
    ) {
        self.content = content
        self.activeName = activeName
        self.presets = presets
    }

    func setContent(_ value: HostContent) { content = value }
    func setActiveName(_ value: String?) { activeName = value }
    func setPresets(_ value: [Preset]) { presets = value }

    func start() async { calls.append(.start) }
    func loadComponent(_ component: AudioUnitComponent) async { calls.append(.loadComponent(component)) }
    func selectPreset(name: String) async { calls.append(.selectPreset(name: name)) }
    func saveCurrentPreset() { calls.append(.saveCurrentPreset) }
    func restoreActivePreset() async { calls.append(.restoreActivePreset) }
    func saveAsNewPreset(name: String) { calls.append(.saveAsNewPreset(name: name)) }
    func renamePreset(from: String, to: String) { calls.append(.renamePreset(from: from, to: to)) }
    func deletePreset(name: String) { calls.append(.deletePreset(name: name)) }
}
