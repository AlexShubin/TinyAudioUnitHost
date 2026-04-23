//
//  AudioInputRouting.swift
//  TinyAudioUnitHost
//
//  Created by Alex Shubin on 22.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

struct AudioInputRouting: Sendable, Equatable {
    var device: AudioInputDevice?
    var channels: [AudioInputDevice.InputChannel]

    static let empty = AudioInputRouting(device: nil, channels: [])
}
