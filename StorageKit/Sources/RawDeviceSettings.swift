//
//  RawDeviceSettings.swift
//  StorageKit
//
//  Created by Alex Shubin on 22.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

public struct RawDeviceSettings: Sendable, Equatable, Codable {
    public var uid: String?
    public var channels: [UInt32]

    public init(uid: String? = nil, channels: [UInt32] = []) {
        self.uid = uid
        self.channels = channels
    }

    public static let empty = RawDeviceSettings()
}
