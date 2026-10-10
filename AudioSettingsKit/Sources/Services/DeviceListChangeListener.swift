//
//  DeviceListChangeListener.swift
//  AudioSettingsKit
//
//  Created by Alex Shubin on 22.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import Common
import CoreAudio
import Foundation

public protocol DeviceListChangeListenerType: Sendable {
    func observeChanges(_ handler: @escaping @Sendable () async -> Void) -> Cancellation
}

struct DeviceListChangeListener: DeviceListChangeListenerType {
    private static let address = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDevices,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )

    func observeChanges(_ handler: @escaping @Sendable () async -> Void) -> Cancellation {
        nonisolated(unsafe) let block: AudioObjectPropertyListenerBlock = { _, _ in
            Task { await handler() }
        }
        guard addPropertyListener(block) == noErr else { return Cancellation {} }
        return Cancellation { removePropertyListener(block) }
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
