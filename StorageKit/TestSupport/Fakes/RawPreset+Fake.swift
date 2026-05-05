//
//  RawPreset+Fake.swift
//  StorageKitTestSupport
//
//  Created by Alex Shubin on 05.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import Foundation
import StorageKit

public extension RawPreset {
    static func fake(
        componentType: UInt32 = 0,
        componentSubType: UInt32 = 0,
        componentManufacturer: UInt32 = 0,
        state: Data = Data()
    ) -> RawPreset {
        RawPreset(
            componentType: componentType,
            componentSubType: componentSubType,
            componentManufacturer: componentManufacturer,
            state: state
        )
    }
}
