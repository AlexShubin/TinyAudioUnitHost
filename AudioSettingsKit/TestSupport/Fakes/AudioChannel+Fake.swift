//
//  AudioChannel+Fake.swift
//  AudioSettingsKitTestSupport
//
//  Created by Alex Shubin on 04.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioSettingsKit

public extension AudioChannel {
    static func fake(id: UInt32 = 1, name: String = "Channel") -> AudioChannel {
        AudioChannel(id: id, name: name)
    }
}
