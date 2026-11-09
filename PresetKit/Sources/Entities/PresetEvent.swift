//
//  PresetEvent.swift
//  PresetKit
//
//  Created by Alex Shubin on 09.11.26.
//  Copyright © 2026 Alex Shubin. All rights reserved.
//

import Foundation

public struct PresetEvent: Sendable, Equatable {
    public enum Kind: Sendable, Equatable {
        case saved
        case restored
    }

    public let id: UUID
    public let kind: Kind
}
