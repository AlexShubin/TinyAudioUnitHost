//
//  PresetEvent+Fake.swift
//  PresetKitTestSupport
//
//  Created by Alex Shubin on 14.10.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import Foundation
@testable import PresetKit

public extension PresetEvent {
    static func fake(id: UUID = UUID(), kind: Kind = .saved) -> PresetEvent {
        PresetEvent(id: id, kind: kind)
    }
}
