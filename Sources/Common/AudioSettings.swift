//
//  AudioSettings.swift
//  TinyAudioUnitHost
//
//  Created by Alex Shubin on 22.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

struct AudioSettings: Sendable, Equatable {
    var inputDevice: AudioDevice?
    var selectedInputChannel: SelectedChannel?

    static let empty = AudioSettings(inputDevice: nil, selectedInputChannel: nil)
}
