//
//  AudioSettings.swift
//  TinyAudioUnitHost
//
//  Created by Alex Shubin on 22.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

struct AudioSettings: Sendable, Equatable {
    var device: AudioInputDevice?
    var selectedInputChannel: SelectedInputChannel?

    static let empty = AudioSettings(device: nil, selectedInputChannel: nil)
}
