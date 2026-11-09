//
//  PresetsModelSpy.swift
//  PresetKitTestSupport
//
//  Created by Alex Shubin on 09.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import Observation
import PresetKit

@MainActor @Observable
public final class PresetsModelSpy: PresetsModelType {
    public enum Calls: Equatable, Sendable {
        case load
        case select(name: String)
        case saveCurrent(chain: [PresetSlot?])
        case restoreActive
        case saveAsNew(name: String, chain: [PresetSlot?])
        case rename(from: String, to: String)
        case delete(name: String)
        case acknowledgeEvent
    }

    public private(set) var calls: [Calls] = []

    public var names: [String] = []
    public var activeName: String?
    public var event: PresetEvent?
    @ObservationIgnored public weak var delegate: PresetsModelDelegate?

    public init() {}

    public func load() async {
        calls.append(.load)
    }

    public func select(name: String) async {
        calls.append(.select(name: name))
    }

    public func saveCurrent(chain: [PresetSlot?]) {
        calls.append(.saveCurrent(chain: chain))
    }

    public func restoreActive() async {
        calls.append(.restoreActive)
    }

    public func saveAsNew(name: String, chain: [PresetSlot?]) {
        calls.append(.saveAsNew(name: name, chain: chain))
    }

    public func rename(from oldName: String, to newName: String) {
        calls.append(.rename(from: oldName, to: newName))
    }

    public func delete(name: String) {
        calls.append(.delete(name: name))
    }

    public func acknowledgeEvent() {
        calls.append(.acknowledgeEvent)
    }
}
