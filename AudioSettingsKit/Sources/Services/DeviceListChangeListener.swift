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
            nonisolated(unsafe) let block: AudioObjectPropertyListenerBlock = { _, _ in
                continuation.yield()
            }
            if addPropertyListener(block) != noErr {
                continuation.finish()
                return
            }
            continuation.onTermination = { _ in
                removePropertyListener(block)
            }
        }
    }

    private func addPropertyListener(_ block: @escaping AudioObjectPropertyListenerBlock) -> OSStatus {
        var address = Self.address
        return AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            nil,
            block
        )
    }

    private func removePropertyListener(_ block: @escaping AudioObjectPropertyListenerBlock) {
        var address = Self.address
        AudioObjectRemovePropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            nil,
            block
        )
    }
}
