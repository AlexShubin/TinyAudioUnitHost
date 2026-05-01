//
//  RawTargetDevice+Fake.swift
//  StorageKitTestSupport
//
//  Created by Alex Shubin on 02.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import StorageKit

public extension RawTargetDevice {
    static func fake(
        input: RawDeviceSettings = .fake(),
        output: RawDeviceSettings = .fake()
    ) -> RawTargetDevice {
        RawTargetDevice(input: input, output: output)
    }
}
