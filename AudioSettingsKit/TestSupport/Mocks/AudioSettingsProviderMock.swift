//
//  AudioSettingsProviderMock.swift
//  AudioSettingsKitTestSupport
//
//  Created by Alex Shubin on 02.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioSettingsKit

public final class AudioSettingsProviderMock: AudioSettingsProviderType, @unchecked Sendable {
    public enum Calls: Equatable, Sendable {
        case current
        case update
    }

    public private(set) var calls: [Calls] = []
    public var settings: AudioSettings

    public init(settings: AudioSettings = .empty) {
        self.settings = settings
    }

    public func current() async -> AudioSettings {
        calls.append(.current)
        return settings
    }

    public func update(_ transform: @Sendable (inout AudioSettings) -> Void) async {
        transform(&settings)
        calls.append(.update)
    }
}
