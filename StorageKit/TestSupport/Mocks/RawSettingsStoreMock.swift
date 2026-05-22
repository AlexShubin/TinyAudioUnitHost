//
//  RawSettingsStoreMock.swift
//  StorageKitTestSupport
//
//  Created by Alex Shubin on 30.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import StorageKit

public final class RawSettingsStoreMock: RawSettingsStoreType, @unchecked Sendable {
    public enum Calls: Equatable, Sendable {
        case current
        case save(RawAudioSettings)
    }

    public private(set) var calls: [Calls] = []
    public var settings: RawAudioSettings

    public init(settings: RawAudioSettings = .empty) {
        self.settings = settings
    }

    public var current: RawAudioSettings {
        calls.append(.current)
        return settings
    }

    public func save(_ settings: RawAudioSettings) {
        self.settings = settings
        calls.append(.save(settings))
    }
}
