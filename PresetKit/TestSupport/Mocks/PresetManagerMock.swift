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
        case load
        case setCurrent(LoadedAudioUnit?)
        case setModified
        case save
        case persistSession
    }

    public private(set) var calls: [Calls] = []
    public var activePreset: ActivePreset?

    public init(activePreset: ActivePreset? = nil) {
        self.activePreset = activePreset
    }

    public func load() -> ActivePreset? {
        calls.append(.load)
        return activePreset
    }

    public func setCurrent(_ loaded: LoadedAudioUnit?) {
        calls.append(.setCurrent(loaded))
    }

    public func setModified() {
        calls.append(.setModified)
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
