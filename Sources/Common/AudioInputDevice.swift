//
//  AudioInputDevice.swift
//  TinyAudioUnitHost
//
//  Created by Alex Shubin on 22.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import CoreAudio

struct AudioInputDevice: Sendable, Identifiable, Hashable {
    let id: AudioDeviceID
    let name: String
    let channels: [AudioInputChannel]
}

struct AudioInputChannel: Sendable, Identifiable, Hashable {
    let id: UInt32
    let name: String
}
