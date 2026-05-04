//
//  AudioSettingsProviderMock.swift
//  AudioSettingsKitTestSupport
//
//  Created by Alex Shubin on 02.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioSettingsKit

public actor AudioSettingsProviderMock: AudioSettingsProviderType {
    public enum Calls: Equatable, Sendable {
        case current
        case update
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

    public func setSettings(_ value: AudioSettings) {
        settings = value
    }
}
