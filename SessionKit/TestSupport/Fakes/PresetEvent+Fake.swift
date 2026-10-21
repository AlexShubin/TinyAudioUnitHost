//
//  PresetEvent+Fake.swift
//  SessionKitTestSupport
//
//  Created by Alex Shubin on 14.10.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import Foundation
@testable import SessionKit

public extension PresetEvent {
    static func fake(id: UUID = UUID(), kind: Kind = .saved) -> PresetEvent {
        PresetEvent(id: id, kind: kind)
    }
}
