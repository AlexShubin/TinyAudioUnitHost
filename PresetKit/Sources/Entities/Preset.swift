//
//  Preset.swift
//  PresetKit
//
//  Created by Alex Shubin on 05.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioUnitsKit
import Foundation

public struct Preset: Sendable, Equatable {
    public let name: String
    public let component: AudioUnitComponent
    public let state: Data

    public init(name: String, component: AudioUnitComponent, state: Data) {
        self.name = name
        self.component = component
        self.state = state
    }
}
