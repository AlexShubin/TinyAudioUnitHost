//
//  RawDeviceSettings.swift
//  StorageKit
//
//  Created by Alex Shubin on 22.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

public struct RawDeviceSettings: Sendable, Equatable, Codable {
    public var uid: String
    public var name: String
    public var selectedChannels: [UInt32]

    public init(uid: String, name: String, selectedChannels: [UInt32]) {
        self.uid = uid
        self.name = name
        self.selectedChannels = selectedChannels
    }
}
