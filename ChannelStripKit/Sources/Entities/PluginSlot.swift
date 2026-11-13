//
//  PluginSlot.swift
//  ChannelStripKit
//
//  Created by Alex Shubin on 09.11.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioUnitsKit
import Foundation

public struct PluginSlot: Sendable, Equatable {
    public let component: AudioUnitComponent
    public let state: Data?
    public let isBypassed: Bool
    public let isInstalled: Bool

    public init(component: AudioUnitComponent, state: Data?, isBypassed: Bool, isInstalled: Bool) {
        self.component = component
        self.state = state
        self.isBypassed = isBypassed
        self.isInstalled = isInstalled
    }
}
