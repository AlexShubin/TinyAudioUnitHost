//
//  AudioDevice.swift
//  TinyAudioUnitHost
//
//  Created by Alex Shubin on 22.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

struct AudioDevice: Sendable, Identifiable, Hashable {
    let id: UInt32
    let uid: String
    let name: String
    let inputChannels: [AudioChannel]
    let outputChannels: [AudioChannel]
}

struct AudioChannel: Sendable, Identifiable, Hashable {
    let id: UInt32
    let name: String
}
