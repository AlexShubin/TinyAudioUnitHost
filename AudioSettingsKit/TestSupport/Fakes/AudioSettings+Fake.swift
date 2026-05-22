//
//  AudioSettings+Fake.swift
//  AudioSettingsKitTestSupport
//
//  Created by Alex Shubin on 02.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import AudioSettingsKit

public extension AudioSettings {
    static func fake(
        inputDevice: AudioDevice? = nil,
        outputDevice: AudioDevice? = nil,
        inputChannel: SelectedChannel? = nil,
        outputChannel: SelectedChannel? = nil,
        bufferSize: UInt32? = nil,
        sampleRate: Float64? = nil,
        savedInput: SavedDevice? = nil,
        savedOutput: SavedDevice? = nil
    ) -> AudioSettings {
        AudioSettings(
            inputDevice: inputDevice,
            outputDevice: outputDevice,
            inputChannel: inputChannel,
            outputChannel: outputChannel,
            bufferSize: bufferSize,
            sampleRate: sampleRate,
            savedInput: savedInput,
            savedOutput: savedOutput
        )
    }
}

public extension SavedDevice {
    static func fake(
        uid: String = "saved-uid",
        name: String? = "Saved Device",
        selectedChannelCount: Int = 2
    ) -> SavedDevice {
        SavedDevice(uid: uid, name: name, selectedChannelCount: selectedChannelCount)
    }
}
