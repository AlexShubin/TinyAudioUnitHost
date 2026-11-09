//
//  ChannelStripModelSpy.swift
//  ChannelStripKitTestSupport
//
//  Created by Alex Shubin on 21.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioUnitsKit
import Foundation
import Observation
import ChannelStripKit

@MainActor @Observable
public final class ChannelStripModelSpy: ChannelStripModelType {
    public enum Calls: Equatable, Sendable {
        case updateHardwareSettings(ChannelStripHardwareSettings?)
        case load(component: AudioUnitComponent, at: Int)
        case unload(at: Int)
        case setBypassed(Bool, at: Int)
        case select(index: Int)
        case replace(with: [PluginSlot?])
    }

    public private(set) var calls: [Calls] = []

    public init() {}

    public var slots: [PluginSlotContent] = []
    public var selectedIndex = 0
    public var isBusy = false

    public func updateHardwareSettings(_ settings: ChannelStripHardwareSettings?) async { calls.append(.updateHardwareSettings(settings)) }
    public func load(component: AudioUnitComponent, at index: Int) async { calls.append(.load(component: component, at: index)) }
    public func unload(at index: Int) async { calls.append(.unload(at: index)) }
    public func setBypassed(_ isBypassed: Bool, at index: Int) { calls.append(.setBypassed(isBypassed, at: index)) }
    public func select(index: Int) { calls.append(.select(index: index)) }
    public func replace(with chain: [PluginSlot?]) async { calls.append(.replace(with: chain)) }
}
