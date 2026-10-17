//
//  SessionModelSpy.swift
//  SessionKitTestSupport
//
//  Created by Alex Shubin on 21.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioUnitsKit
import Foundation
import Observation
import SessionKit

@MainActor @Observable
public final class SessionModelSpy: SessionModelType {
    public enum Calls: Equatable, Sendable {
        case load
        case updateHardwareSettings(SessionHardwareSettings?)
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

    public private(set) var calls: [Calls] = []

    public init() {}

    public var slots: [PluginSlotContent] = []
    public var selectedIndex = 0
    public var isBusy = false
    public var canSavePreset = false
    public var activePresetName: String?
    public var presets: [String] = []
    public var presetEvent: PresetEvent?

    public func load() async { calls.append(.load) }
    public func updateHardwareSettings(_ settings: SessionHardwareSettings?) async { calls.append(.updateHardwareSettings(settings)) }
    public func acknowledgePresetEvent() { calls.append(.acknowledgePresetEvent) }
    public func load(_ component: AudioUnitComponent, at index: Int) async { calls.append(.loadComponent(component, at: index)) }
    public func unload(at index: Int) async { calls.append(.unload(at: index)) }
    public func setBypassed(_ isBypassed: Bool, at index: Int) { calls.append(.setBypassed(isBypassed, at: index)) }
    public func select(_ index: Int) { calls.append(.select(index)) }
    public func selectPreset(name: String) async { calls.append(.selectPreset(name: name)) }
    public func saveCurrentPreset() { calls.append(.saveCurrentPreset) }
    public func restoreActivePreset() async { calls.append(.restoreActivePreset) }
    public func saveAsNewPreset(name: String) { calls.append(.saveAsNewPreset(name: name)) }
    public func renamePreset(from: String, to: String) { calls.append(.renamePreset(from: from, to: to)) }
    public func deletePreset(name: String) { calls.append(.deletePreset(name: name)) }
}
