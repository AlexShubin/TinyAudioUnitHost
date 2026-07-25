//
//  MidiDevice+Fake.swift
//  AudioSettingsKitTestSupport
//
//  Created by Alex Shubin on 02.07.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioSettingsKit

public extension MidiDevice {
    static func fake(
        ref: UInt32 = 1,
        uid: Int32 = 1,
        name: String = "Test MIDI Device"
    ) -> MidiDevice {
        MidiDevice(ref: ref, uid: uid, name: name)
    }
}
