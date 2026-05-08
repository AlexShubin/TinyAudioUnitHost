//
//  PresetManagerMock.swift
//  PresetKitTestSupport
//
//  Created by Alex Shubin on 08.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioUnitsKit
import PresetKit

public actor PresetManagerMock: PresetManagerType {
    public enum Calls: Equatable, Sendable {
        case loadActive
        case setCurrent(LoadedAudioUnit?)
        case save
        case persistSession
    }

    public private(set) var calls: [Calls] = []
    public var activePreset: ActivePreset?

    public init(activePreset: ActivePreset? = nil) {
        self.activePreset = activePreset
    }

    public func loadActive() -> ActivePreset? {
        calls.append(.loadActive)
        return activePreset
    }

    public func setCurrent(_ loaded: LoadedAudioUnit?) {
        calls.append(.setCurrent(loaded))
    }

    public func save() {
        calls.append(.save)
    }

    public func persistSession() {
        calls.append(.persistSession)
    }

    public func setActivePreset(_ value: ActivePreset?) {
        activePreset = value
    }
}
