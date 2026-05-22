//
//  RawActivePresetState+Fake.swift
//  StorageKitTestSupport
//
//  Created by Alex Shubin on 18.05.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import StorageKit

public extension RawActivePresetState {
    static func fake(name: String = "test") -> RawActivePresetState {
        RawActivePresetState(name: name)
    }
}
