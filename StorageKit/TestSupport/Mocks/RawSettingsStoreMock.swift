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
        case update
        case current
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

    public func update(_ transform: (inout RawAudioSettings) -> Void) {
        transform(&settings)
        calls.append(.update)
    }
}
