//
//  DeviceListChangeListener.swift
//  AudioSettingsKit
//
//  Created by Alex Shubin on 22.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import CoreAudio
import Foundation

public protocol DeviceListChangeListenerType: Sendable {
    /// Yields whenever CoreAudio reports a change to the system device list
    /// (e.g. an interface is powered on/off, USB plug/unplug). Fires regardless
    /// of whether an AVAudioEngine is active — unlike `AVAudioEngineConfigurationChange`.
    func stream() -> AsyncStream<Void>
}

struct DeviceListChangeListener: DeviceListChangeListenerType {
    private static let address = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDevices,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )

    func stream() -> AsyncStream<Void> {
        AsyncStream { continuation in
            let block: AudioObjectPropertyListenerBlock = { _, _ in
                continuation.yield()
            }
            var address = Self.address
            let status = AudioObjectAddPropertyListenerBlock(
                AudioObjectID(kAudioObjectSystemObject),
                &address,
                nil,
                block
            )
            if status != noErr { continuation.finish() }
        }
    }
}
