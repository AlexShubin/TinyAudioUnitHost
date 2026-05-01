//
//  RawDeviceSettings+Fake.swift
//  StorageKitTestSupport
//
//  Created by Alex Shubin on 30.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import StorageKit

public extension RawDeviceSettings {
    static func fake(
        uid: String? = nil,
        channels: [UInt32] = []
    ) -> RawDeviceSettings {
        RawDeviceSettings(uid: uid, channels: channels)
    }
}
