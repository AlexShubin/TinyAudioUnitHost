//
//  AudioInputRoutingStore.swift
//  TinyAudioUnitHost
//
//  Created by Alex Shubin on 22.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

protocol AudioInputRoutingStoreType: Sendable {
    func current() async -> AudioInputRouting
    func update(_ routing: AudioInputRouting) async
}

final actor AudioInputRoutingStore: AudioInputRoutingStoreType {
    private var routing: AudioInputRouting = .empty

    func current() -> AudioInputRouting { routing }
    func update(_ routing: AudioInputRouting) { self.routing = routing }
}
