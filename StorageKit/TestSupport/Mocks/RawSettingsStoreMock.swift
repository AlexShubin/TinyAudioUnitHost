//
//  RawSettingsStoreMock.swift
//  StorageKitTestSupport
//
//  Created by Alex Shubin on 30.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import StorageKit

public actor RawSettingsStoreMock: RawSettingsStoreType {
    public enum Calls: Equatable {
        case update
        case current
    }

    public private(set) var calls: [Calls] = []
    public var settings: RawAudioSettings

    public init(settings: RawAudioSettings = .empty) {
        self.settings = settings
    }

    public func current() -> RawAudioSettings {
        calls.append(.current)
        return settings
    }

    public func update(_ transform: @Sendable (inout RawAudioSettings) -> Void) {
        transform(&settings)
        calls.append(.update)
    }

    public func setSettings(_ value: RawAudioSettings) {
        settings = value
    }
}
