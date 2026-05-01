//
//  DeviceSettings+Fake.swift
//  StorageKitTestSupport
//
//  Created by Alex Shubin on 30.04.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import StorageKit

public extension DeviceSettings {
    static func fake(
        deviceUID: String? = nil,
        selectedChannelIDs: [UInt32]? = nil
    ) -> DeviceSettings {
        DeviceSettings(deviceUID: deviceUID, selectedChannelIDs: selectedChannelIDs)
    }
}
