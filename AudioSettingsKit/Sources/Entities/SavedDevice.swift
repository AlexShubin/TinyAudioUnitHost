//
//  SavedDevice.swift
//  AudioSettingsKit
//
//  Created by Alex Shubin on 22.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

/// Pointer to a previously-persisted device. Non-nil whenever a UID was stored,
/// regardless of whether the device currently resolves against live system state.
/// `selectedChannelCount` is how many channels the user picked when they saved
/// this device — 0 means the device was saved but no channels were ever chosen.
public struct SavedDevice: Sendable, Equatable, Hashable {
    public let uid: String
    public let name: String
    public let selectedChannelCount: Int

    public init(uid: String, name: String, selectedChannelCount: Int) {
        self.uid = uid
        self.name = name
        self.selectedChannelCount = selectedChannelCount
    }
}
