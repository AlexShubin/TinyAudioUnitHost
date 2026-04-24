//
//  AudioSettingsStore.swift
//  TinyAudioUnitHost
//
//  Created by Alex Shubin on 22.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

protocol AudioSettingsStoreType: Sendable {
    func current() async -> AudioSettings
    func update(_ transform: @Sendable (inout AudioSettings) -> Void) async
}

final actor AudioSettingsStore: AudioSettingsStoreType {
    private var settings: AudioSettings = .empty

    func current() -> AudioSettings { settings }

    func update(_ transform: @Sendable (inout AudioSettings) -> Void) {
        transform(&settings)
    }
}
