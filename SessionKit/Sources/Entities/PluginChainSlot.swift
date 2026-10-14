//
//  PluginChainSlot.swift
//  SessionKit
//
//  Created by Alex Shubin on 11.10.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioUnitsKit
import Foundation

public struct PluginChainSlot: Sendable, Equatable {
    public let component: AudioUnitComponent
    public let state: Data?

    public init(component: AudioUnitComponent, state: Data?) {
        self.component = component
        self.state = state
    }
}
