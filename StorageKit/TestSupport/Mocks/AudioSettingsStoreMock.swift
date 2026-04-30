//
//  AudioSettingsStoreMock.swift
//  StorageKitTestSupport
//
//  Created by Alex Shubin on 30.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import Common
import StorageKit

public actor AudioSettingsStoreMock: AudioSettingsStoreType {
    public enum Calls: Equatable {
        case update
        case current
    }

    public private(set) var calls: [Calls] = []
    public var settings: AudioSettings

    public init(settings: AudioSettings = .empty) {
        self.settings = settings
    }

    public func current() -> AudioSettings {
        calls.append(.current)
        return settings
    }

    public func update(_ transform: @Sendable (inout AudioSettings) -> Void) {
        transform(&settings)
        calls.append(.update)
    }
}
