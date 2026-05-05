//
//  EngineMock.swift
//  EngineKitTestSupport
//
//  Created by Alex Shubin on 04.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioUnitsKit
import EngineKit
import Foundation

public actor EngineMock: EngineType {
    public enum Calls: Equatable, Sendable {
        case load(AudioUnitComponent, Data?)
        case reload
    }

    public private(set) var calls: [Calls] = []
    public var loadResult: LoadedAudioUnit?

    public init(loadResult: LoadedAudioUnit? = nil) {
        self.loadResult = loadResult
    }

    public func load(component: AudioUnitComponent, state: Data?) async -> LoadedAudioUnit? {
        calls.append(.load(component, state))
        return loadResult
    }

    public func reload() async {
        calls.append(.reload)
    }

    public func setLoadResult(_ value: LoadedAudioUnit?) {
        loadResult = value
    }
}
